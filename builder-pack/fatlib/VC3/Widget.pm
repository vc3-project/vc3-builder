#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Widget;
use Carp;
use POSIX ":sys_wait_h";
use IO::Handle;
use Digest::Perl::MD5 qw(md5_hex);
use Cwd;
use File::Temp qw/tempdir/;
use File::Spec::Functions qw/catfile rel2abs/;
use JSON::Tiny;

use VC3::Ribbon;

# Attributes:
# version, source, dependencies, wrapper, prologue, environment_variables, environment_autovars, phony
sub new {
    my ($class, $pkg, $json_description) = @_;

    my $self = bless {}, $class;

    $self->package($pkg);
    $self->available(1);

    $self->source($json_description->{source});

    if($json_description->{version} eq 'auto') {
        $self->from_system(1);
        eval { $self->version($self->compute_auto_version()) };
        if($@) {
            $self->available(0);
        }
    } else {
        $self->version($json_description->{version});
        $self->from_system(0);
    }

    $self->dependencies($json_description->{dependencies});
    $self->wrapper($json_description->{wrapper});
    $self->prologue($json_description->{prologue});
    $self->environment_variables($json_description->{'environment-variables'});
    $self->environment_autovars($json_description->{'environment-autovars'});

    # should always be executed
    $self->phony($json_description->{phony});

    # should recipe be executed locally when using parallel builds?
    $self->local($json_description->{local});


    if($self->available) {
        my $majminbug = $self->version->normal;
        $majminbug =~ s/^v([0-9]+\.[0-9]+\.[0-9]+)/$1/;

        my $majmin = $self->version->normal;
        $majmin    =~ s/^v([0-9]+\.[0-9]+)\..*/$1/;

        $self->add_widget_variable('VERSION', $majmin);
        $self->add_widget_variable('VERSION_FULL', $majminbug);

        if($self->package->options) {
            $self->add_widget_variable('OPTIONS', @{$self->package->options});
        }

        # initialize root dir variable. we use unless here becase root_dir
        # depends on machine target, which is still not set until we process
        # all the operating-system-distribution's
        unless($self->package->type eq 'operating-system-distribution') {
            $self->root_dir();
        }
    }

    unless($self->source) {
        my $null_source = {};
        $null_source->{type}   = 'generic';
        $null_source->{recipe} = ['echo "no explicit recipe given"'];

        $self->source($null_source);
    }

    return $self;
}

sub to_hash {
    my ($self) = @_;

    my $wh = {};

    $wh->{version}       = $self->version;
    $wh->{phony}         = $self->phony;
    $wh->{local}         = $self->local;
    $wh->{source}        = $self->source->to_hash;
    $wh->{dependencies}  = $self->dependencies;
    $wh->{wrapper}       = $self->wrapper;
    $wh->{prologue}      = $self->prologue;
    $wh->{'environment-variables'} = $self->environment_variables;

    # environment-autovars already included in environment-variables

    for my $k (keys %{$wh}) {
        unless(defined $wh->{$k}) {
            delete $wh->{$k};
        }
    }

    return $wh;
}

sub add_widget_variable {
    my ($self, $varname, $value) = @_;

    $varname = $self->widget_var($varname);

    my $var = {
        name     => $varname,
        value    => $value,
        clobber  => 1,
        absolute => 1
    };

    $self->environment_variables([$var]);
}

sub widget_var {
    my ($self, $varname) = @_;

    my $expanded = "VC3_${varname}_" . uc($self->package->name);

    # replace - with _, as env vars cannot have - in their names.
    $expanded =~ s/-/_/g;

    return $expanded;
}

sub package {
    my ($self, $new_pkg) = @_;

    $self->{package} = $new_pkg if($new_pkg);

    croak 'No package given'
    unless($self->{package}); 

    return $self->{package};
}

sub ribbon {
    my ($self) = @_;

    unless($self->{ribbon}) {
        $self->{ribbon} = VC3::Ribbon->new($self->package->name, $self->bookeeping_dir, $self->package->bag->tmp_dir, $self->checksum($self->source->recipe));
    }

    return $self->{ribbon};
}

sub version {
    my ($self, $new_version) = @_;

    if($new_version) {
        $self->{version} = version->declare($new_version);
    }

    unless($self->{version}) {
        croak 'No version given';
    }

    return $self->{version};
}

sub dependencies {
    my ($self, $new_dependencies) = @_;

    if($new_dependencies) {
        $self->{dependencies} = $new_dependencies;
    }

    my %deps;
    if($self->package->dependencies) {
        %deps = %{$self->package->dependencies};
    }

    for my $d (keys %{$self->{dependencies}}) {
        $deps{$d} = $self->{dependencies}->{$d};
    }

    return \%deps;
}

sub source {
    my ($self, $new_source) = @_;

    if($new_source) {
        $self->{source} = VC3::Source::new($self, $new_source);
    }

    return $self->{source};
}

sub prologue {
    my ($self, $new_prologue) = @_;

    $self->{prologue} = $new_prologue if($new_prologue);

    my $prologue = $self->{prologue} || $self->package->prologue;

    return $prologue;
}

sub wrapper {
    my ($self, $new_wrapper) = @_;

    $self->{wrapper} = $new_wrapper if($new_wrapper);

    my $wrapper = $self->{wrapper} || $self->package->wrapper;

    return $wrapper;
}


sub environment_variables {
    my ($self, $new_vars) = @_;

    $self->{environment_variables} ||= [];

    if($new_vars) {
        unshift @{$self->{environment_variables}}, @{$new_vars};
    }

    return [ @{$self->{environment_variables}}, @{$self->package->environment_variables} ];
}

sub environment_autovars {
    my ($self, $new_autovars) = @_;

    my %mappings;
    $mappings{PATH}               = 'bin';
    $mappings{LD_LIBRARY_PATH}    = 'lib';
    $mappings{LIBRARY_PATH}       = 'lib';
    $mappings{C_INCLUDE_PATH}     = 'include';
    $mappings{CPLUS_INCLUDE_PATH} = 'include';
    $mappings{PKG_CONFIG_PATH}    = 'lib/pkgconfig';
    $mappings{PYTHONPATH}         = 'lib/python${VC3_VERSION_PYTHON}/site-packages';
    $mappings{PERL5LIB}           = 'lib/perl5/site_perl';

    if($new_autovars) {
        $self->{environment_autovars} = $new_autovars;
    }

    my @autovars;
    if($self->package->environment_autovars) {
        push @autovars, @{$self->package->environment_autovars};
    }

    if($self->{environment_autovars}) {
        push @autovars, @{$self->{environment_autovars}};
    }

    $self->{environment_variables} ||= [];
    for my $var (@autovars) {
        my $target = $mappings{$var};

        unless($target) {
            die "Unrecognized auto-variable '$var'";
        }

        push @{$self->{environment_variables}}, { 'name' => $var, 'value' => $target };
    }

    return \@autovars;
}

sub phony {
    my ($self, $new_phony) = @_;

    $self->{phony} = $new_phony if(defined $new_phony);

    my $phony = $self->{phony} || $self->package->phony;

    return $phony;
}

sub local {
    my ($self, $new_local) = @_;

    $self->{local} = $new_local if($new_local);

    return $self->{local};
}

sub from_system {
    my ($self, $new_from_system) = @_;

    $self->{from_system} = $new_from_system if(defined $new_from_system);

    return $self->{from_system};
}

sub available {
    my ($self, $new_available) = @_;

    $self->{available} = $new_available if(defined $new_available);

    return $self->{available};
}

sub root_dir {
    my ($self, $new) = @_;

    my $old = $self->{root_dir};

    my $var_value;

    if($new) {
        $self->{root_dir} = $new;
        $var_value = $new;
    }

    unless($self->{root_dir}) {
        my $rel = catfile($self->package->bag->target, $self->package->name, $self->version->normal);
        $self->{root_dir} = catfile($self->package->bag->root_dir, $rel);
        $var_value = catfile('${VC3_ROOT}', '${VC3_MACHINE_TARGET}', $self->package->name, 'v${' . $self->widget_var('VERSION_FULL') . '}');
    }

    if(!$old || $old ne $self->{root_dir}) {
        $self->add_widget_variable('ROOT', $var_value);
    }

    return $self->{root_dir};
}

sub bookeeping_dir {
    my ($self, $relative) = @_;

    my $rel = catfile($self->package->bag->target, $self->package->name, $self->version->normal);

    if($relative) {
        return $rel;
    }

    return catfile($self->package->bag->root_dir, $rel);
}

sub build_dir {
    my ($self) = @_;

    unless($self->{build_dir}) {
        my $root     = catfile($self->package->bag->root_dir, 'builds');

        unless(-d $root) {
            File::Path::make_path($root);
        }

        my $template = catfile($root, $self->package->name . '.XXXXXX');

        my $tmpdir   = File::Temp::tempdir($template, CLEANUP => 1);
        $self->{build_dir} = $tmpdir;
    }

    return $self->{build_dir};
}

sub build_log {
    my ($self) = @_;
    my $log_name = catfile($self->bookeeping_dir, $self->package->name . '-build-log');

    return $log_name;
}

sub say {
    my $self = shift @_;

    return $self->package->bag->say(@_);
}

sub consolidate_environment_variables {
    my ($self, $expansion) = @_; 

    my $vars = $self->environment_variables
    || return;

    for my $var (reverse @{$vars}) {

        my $name = $var->{name}
        || carp "Environment variable does not have a name.";

        my $value = $var->{value}
        || carp "Environment variable '$name' did not define a value.";

        my $clobber  = $var->{clobber};
        my $absolute = $var->{absolute};

        if($expansion->{$name} && $clobber) {
            my @old_value = @{$expansion->{$name}};
            my $n = @old_value;
            if($n > 1) {
                carp("Asked to clobber variable '$name', but it already had a value.\n"
                    . "'$value' <> '" . join(',', @old_value) . "'\n");
            }
        }

        $expansion->{$name} ||= [];

        my @paths;
        if($clobber) {
            # when clobber, we use the value as is, and remove previous expansions.
            @paths = ($value);
            $expansion->{$name} = [];
        } else {
            # otherwise, split paths on :
            @paths = split /:/, $value;
        }

        my @current_expansions;
        for my $path (@paths) {
            if(!$absolute) {
                if($self->root_dir eq $self->bookeeping_dir) {
                    $path = catfile('${' . $self->widget_var('ROOT') . '}', $path);
                } else {
                    $path = catfile($self->root_dir, $path);
                }
            }

            push @current_expansions, $path;
        }

        unshift @{$expansion->{$name}}, @current_expansions;
    }
}

sub error_debug_info {
    my ($self, $eval_error) = @_;

    print "'", $self->package->name, "' failed to build for ", $self->package->bag->target, "\n";

    if($eval_error) {
        print $eval_error, "\n";
    }

    if(-f $self->build_log) {
        print "Last lines of log file:\n";
        system('tail', $self->build_log);
    }
}


sub process_error {
    my ($self, $sh_on_error, $eval_error, $status) = @_;

    if($eval_error || $status) {
        $self->error_debug_info($eval_error);

        if($sh_on_error) {
            warn $@ if $@;

            my $cwd = getcwd();

            $self->package->bag->shell_user();

            chdir $cwd;
        }
    }
}

sub checksum {
    my ($self, $load) = @_;

    if(!$self->{checksum}) {
        $load ||= 'no source';

        my $txt = $self->hash_to_canonical_str($load);
        my $dgt = md5_hex($txt);

        $self->{checksum} = $dgt;
    }

    return $self->{checksum};
}

sub hash_to_canonical_str {
    my ($self, $ref) = @_;

    my $str;

    if(ref($ref) eq 'HASH') {
        my @ks = sort { $a cmp $b } keys %{$ref};

        $str 
        = '{'
        . join(',', map { $_ .  ':' . $self->hash_to_canonical_str($ref->{$_}) } @ks)
        . '}';
    } elsif(ref($ref) eq 'ARRAY') {
        $str 
        = '['
        . join(',', map { $self->hash_to_canonical_str($_) } @{$ref})
        . ']';
    } else {
        $str = $ref;
    }

    return $str;
}


sub msgs_manual_requirements {
    my ($self) = @_;

    my $source = $self->source;

    if(!$self->source->check_manual_requirements()) {
        return $self->source->msg_manual_requirement();
    }
}

sub prepare_recipe_sandbox {
    my ($self, $source, $no_erase) = @_;

    # clear build directory, to avoid bugs from uncleaned sources.
    my $build = $self->build_dir;
    if( -d $build ) {
        File::Path::rmtree($build);
    }

    # clear destination directory, to make sure we are running what we believe
    # we are running.
    unless($no_erase) {
        my $dir = $self->root_dir;
        if( -d $dir ) {
            File::Path::rmtree($dir);
        }

        if($self->root_dir ne $self->bookeeping_dir) {
            my $dir = $self->bookeeping_dir;
            if( -d $dir ) {
                File::Path::rmtree($dir);
            }
        }
    }

    # create the dirs we removed above.
    File::Path::make_path($self->build_dir);
    File::Path::make_path($self->root_dir);
    File::Path::make_path($self->bookeeping_dir);

    # make sure tmp dir exists
    File::Path::make_path($self->package->bag->tmp_dir);

    # set the destination directory as an environment variable before
    # setting up the shell, so that the child created inherets it.
    $self->package->bag->add_builder_variable('VC3_PREFIX', $self->root_dir);
    $self->package->bag->add_builder_variable('VC3_BUILD',  $self->build_dir);
    $self->package->bag->add_builder_variable('VC3_FILES',  join(" ", @{$source->files}));
}

sub cleanup_recipe_sandbox {
    my ($self, $result) = @_;

    $self->package->bag->del_builder_variable('VC3_PREFIX');
    $self->package->bag->del_builder_variable('VC3_BUILD');
    $self->package->bag->del_builder_variable('VC3_FILES');

    if($result eq '0') {
        File::Path::rmtree($self->build_dir);
        $self->ribbon->commit('DONE');
    }

    # we do not delete the buildir in case of error, to ease debugging.
}

sub setup_build_shell {
    my ($self, @log_messages) = @_;

    # log the recipe used. Since we are opening sh with -e, the recipe executes
    # as if all steps were &&-ed together.
    open(my $build_log, '>', $self->build_log);
    print { $build_log } join("\n && ", @log_messages . "\n");
    close $build_log;

    # open sh with -e. This terminates the shell at the first step that returns
    # a non-zero status.
    my ($pid, $build_in) = $self->package->bag->shell();

    croak "Could not execute shell for building."
    unless $build_in;

    # redirect all output to our log file.
    print { $build_in } 'exec 1>> ' . $self->build_log . "\n";
    print { $build_in } "exec 2>&1\n";
    print { $build_in } "set -ex\n";

    # return the stdin of the shell, and the pid so we can wait for it.
    return ($pid, $build_in);
}

sub shell {
    my ($self) = @_;
    return $self->package->bag->shell();
}

sub compute_auto_version {
    my ($self, $root) = @_;

    unless($self->source->auto_version) {
        die "I don't know how to compute the version of '" . $self->package->name . "'\n";
    }

    if($root) {
        $self->package->bag->add_builder_variable('VC3_PREFIX', $root);
    }

    my ($pid, $auto_in) = $self->package->bag->shell();

    if($root) {
        $self->package->bag->del_builder_variable('VC3_PREFIX');
    }

    die "Could not execute shell for auto-version.\n"
    unless $auto_in;

    my $template = catfile($self->package->bag->tmp_dir, $self->package->name . 'XXXXXX');
    my $fh = File::Temp->new(template => $template, unlink => 1);
    close($fh);
    
    my $fname = $fh->filename;

    # redirect all output to our log file.
    print { $auto_in } 'exec 1> ' . $fname . "\n";
    print { $auto_in } "exec 2>&1\n";
    print { $auto_in } "set -ex\n";

    if($root) {
        print { $auto_in } q(export PATH="${VC3_PREFIX}/bin":"$PATH") . "\n";
    }

    for my $step (@{$self->source->auto_version}) {
        print { $auto_in } "$step\n";
    }
    print { $auto_in } "exit 0\n";

    my $status = -1;
    eval { close $auto_in; $status = $? };


    open(my $f, '<', $fname) || die 'Did not produce auto-version file';
    my @lines;
    my $version;
    while( my $line = <$f>) {
        push @lines, $line;
        if($line =~ m/^VC3_VERSION_SYSTEM:\s*v?(?<version>([0-9]+(\.?[0-9]){0,3}))$/) {
            $version = $+{version};
            chomp($version);
            last;
        }
    }
    close $f;
    if(!$version) {
        die $self->package->name . " did not produce version information.\n";
    }

    return $version;
}


sub compute_os_distribution {
    my ($self) = @_;

    unless($self->source) {
        die "I don't know how to find the distribution from '" . $self->package->name . "'\n";
    }

    my ($pid, $auto_in) = $self->package->bag->shell();

    die "Could not execute shell for operating-system-distro.\n"
    unless $auto_in;

    my $template = catfile($self->package->bag->tmp_dir, $self->package->name . 'XXXXXX');
    my $fh = File::Temp->new(template => $template, unlink => 1);
    close($fh);
    
    my $fname = $fh->filename;

    # redirect all output to our log file.
    print { $auto_in } 'exec 1> ' . $fname . "\n";
    print { $auto_in } "exec 2>&1\n";
    print { $auto_in } "set -ex\n";

    for my $step (@{$self->source->recipe}) {
        print { $auto_in } "$step\n";
    }
    print { $auto_in } "exit 0\n";

    my $status = -1;
    eval { close $auto_in; $status = $? };

    if($@) {
        warn "$@\n";
    }

    open(my $f, '<', $fname) || die 'Did not produce a distribution file';
    my @lines;
    my $distro;
    while( my $line = <$f>) {
        push @lines, $line;
        if($line =~ m/^VC3_MACHINE_DISTRIBUTION:\s*(?<distro>.*)/) {
            $distro = $+{distro};
            chomp($distro);
            last;
        }
    }
    close $f;
    if(!$distro) {
        return;
    }

    return $self->distro_canonical_name($distro);
}

sub distro_canonical_name {
    my ($self, $distro) = @_;

    my ($name, $version) = ($distro =~ m/(.+) (.+)/);

    if($name =~ m/(redhat|rhel|centos)/) {
        $name = 'redhat';
    } elsif($name =~ m/debian/) {
        $name = 'debian';
    } elsif($name =~ m/ubuntu/) {
        $name = 'ubuntu';
    } elsif($name =~ m/opensuse/) {
        $name = 'opensuse';
    }

    return "$name$version";
}

1;

