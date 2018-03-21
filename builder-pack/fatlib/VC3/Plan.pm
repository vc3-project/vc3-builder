package VC3::Plan;
use File::Spec::Functions qw/catfile rel2abs/;
use JSON::Tiny;

use VC3::Plan::Element;

sub new {
    my ($class, $bag, $parent) = @_;

    my $self = bless {}, $class;

    $self->bag($bag);

    $self->elements($parent && $parent->elements || {});

    return $self;
}

sub bag {
    my ($self, $new) = @_;

    if($new) {
        $self->{bag} = $new;
    }

    return $self->{bag};
}

sub say {
    my ($self, @rest) = @_;

    return $self->bag->say(@rest);
}

sub elements {
    my ($self, $new) = @_;

    if($new) {
        $self->{elements} = \%{ $new };
    }

    return $self->{elements};
}

sub element_of {
    my ($self, $name) = @_;

    return $self->elements->{$name};
}

sub requirements {
    my ($self) = @_;

    unless($self->{requirements}) {
        $self->{requirements} = [];
    }

    return $self->{requirements};
}

sub add_target {
    my ($self, $name, $min, $max) = @_;

    $self->bag->{indent_level}++;

    $self->say("Plan:    $name => [@{[$min || '']}, @{[$max || '']}]");

    my $available = $self->bag->widgets_of($name);
    for my $widget (@{$available}) {

        unless($widget->available) {
            next;
        }

        # This is a naive search!
        # We also want to check for different order of targets.
        if($self->add_widget($widget, $min, $max)) {
            $self->bag->{indent_level}--;
            return 1;
        }
    }

    $self->say("Failure: $name => [@{[$min || '']}, @{[$max || '']}]");
    $self->bag->{indent_level}--;

    return 0;
}

sub operating_system {
    my ($self, $new_os) = @_;

    $self->{operating_system} = $new_os if($new_os);

    return $self->{operating_system};
}

sub add_main_targets {
    my ($self, @requires) = @_;

    my $root_entry = { version => version->declare('v0.0.1'), phony => 1, dependencies => {} };

    for my $req (@requires) {
        my ($name, $min, $max) = $self->parse_requirement($req);

        my $versions = [];
        push @{$versions}, $min if($min);
        push @{$versions}, $max if($max);

        $root_entry->{dependencies}{$name} = $versions;
        
        unless($self->add_target($name, $min, $max)) {
            die "Could not find plan for $req.\n";
        }

        push @{$self->requirements}, $name;
    }

    return 1;
}

sub parse_requirement {
    my ($self, $req) = @_;

    $req =~ m/
    ^
    (?<name> [A-z0-9_-]+)
    (:v?                      # start of min version
    (?<min> [^:]*)
    (:v?                    # start of max version
    (?<max> [^:]*)
    )?)?
    $
    /x;

    my ($name, $min, $max) = ($+{name}, $+{min}, $+{max});

    if($min eq 'auto') {
        undef $min;
    }

    if($max eq 'auto') {
        undef $max;
    }

    if(!$min && $max) {
        $min = 'v0.0.1';
    }

    # turn into version strings
    eval {
        $min = version->declare($min) if($min);
        $max = version->declare($max) if($max);
    };
    if($@) {
        die "Versions should be of the form: MAJOR.MINOR.REVISION\n";
    }


    return ($name, $min, $max);
}

sub version_str {
    my ($self, $v) = @_;

    return ''         unless $v;
    return $v->normal if $v->isa('version');
    return version->parse($v)->normal;
}

sub add_widget {
    my ($self, $widget, $min, $max) = @_;

    my $version = $widget->version;

    $self->say("Try:     " . $widget->package->name . " => @{[$version->normal]}");

    if($min && $min gt $version || $max && $max lt $version) {
        $self->say("Incorrect version: @{[$version->normal]} => [@{[$self->version_str($min)]},@{[$self->version_str($max)]}]");
        return 0;
    }

    my $saved_state = $self->elements();

    my $p = $self->elements->{$widget->package->name};
    my $e = $self->refine($widget, $p, $min, $max);

    my $success;
    if($p && !$e) {
        $self->say("conflicting versions: @{[$widget->package->name]} [@{[ $self->version_str($p->{min}) ]}, @{[ $self->version_str($p->{max})]} <=> [@{[$self->version_str($min)]}, @{[$self->version_str($max)]}]");
        $success = 0;
    } elsif(!$e) {
        $success = 0;
        die('bug, this should not happen.');
    } else {
        $self->say("Refining version: @{[$widget->package->name, $version]} => [@{[$self->version_str($e->{min})]}, @{[$self->version_str($e->{max})]}]");
        if($self->add_dependencies($widget->dependencies)) {
            if($widget->source) {
                my $s = $self->add_source($widget->source);
                if($s) {
                    $success = 1;
                } else {
                    $self->say("could not add source for: @{[$widget->package->name, $version]} => [@{[$self->version_str($min)]}, @{[$self->version_str($max)]}]");
                    $success = 0;
                }
            } else {
                $success = 1;
            }
        } else {
            $self->say("could not set dependencies for: @{[$widget->package->name]} @{[$version->normal]} => [@{[$self->version_str($min)]}, @{[$self->version_str($max)]}]");
            $success = 0;
        }
    }

    if($success) {
        # add new step to plan
        $self->elements->{$widget->package->name} = $e;
        $self->say("Success: @{[$widget->package->name]} @{[$e->widget->version->normal]} => [@{[$self->version_str($min)]}, @{[$self->version_str($max)]}]");
    } else {
        # restore old plan on error
        $self->elements($saved_state);
    }

    return $success;
}

sub add_dependencies {
    my ($self, $dependencies) = @_;

    my $saved_state = $self->elements();

    my $success = 1;
    for my $name (keys %{$dependencies}) {

        my ($min, $max) = @{$dependencies->{$name}};
        unless($self->add_target($name, $min, $max)) {
            $success = 0;
            last;
        }
    }

    unless($success) {
        $self->elements($saved_state);
    }

    return $success;
}

sub add_source {
    my ($self, $source) = @_;

    my $saved_state = $self->elements();

    if($source->isa('VC3::Source::System')) {
        unless($self->bag->{system}{$source->widget->package->name}) {
            next if $self->bag->{no_system}{ALL};
            next if $self->bag->{no_system}{$source->widget->package->name};
        }
    }

    my $exit_status = -1;
    eval { $exit_status = $source->check_prerequisites() };

    if($exit_status) {
        $self->say("Fail-prereq: " . $source->widget->package->name . '-' . $source->widget->version->normal);
        return undef;
    }

    if($self->add_dependencies($source->dependencies)) {
        return $source;
    }

    $self->elements($saved_state);
    return undef;
}


sub refine {
    my ($self, $widget, $p, $min, $max) = @_;

    my $e = VC3::Plan::Element->new($widget, $min, $max);

    if($p) {
        return $e->refine($min, $max);
    } else {
        return $e;
    }
}

sub order {
    my ($self, $set) = @_;

    if($set) {
        my $ordinals = $self->order_aux();
        my @ordered = sort { ($ordinals->{$a} <=> $ordinals->{$b}) || ($a cmp $b) } keys %{$ordinals};
        $self->{order} = [ map { $self->elements->{$_}{widget} } @ordered ];
    }

    return $self->{order};
}

sub order_aux {
    my ($self) = @_;

    my $ordinal_of = {};

    my @names = keys %{$self->elements};

    for my $name (@names) {
        $ordinal_of->{$name} = 1;
    }

    my $to_go = @names;

    while($to_go >= 0) {
        my $change = 0;

        $to_go--;

        for my $name (@names) {
            my $e = $self->elements->{$name};
            my $o = $ordinal_of->{$name};

            my @deps;

            my $w = $e->{widget};

            if($w->dependencies) {
                push @deps, keys %{$w->dependencies};
            }

            if($w->source->dependencies) {
                push @deps, keys %{$w->source->dependencies};
            }

            my $max = $o;
            if(@deps) {
                $max = 1 + List::Util::max( @{$ordinal_of}{@deps} );
            }

            if($max != $o) {
                $change = 1;
                $ordinal_of->{$w->package->name} = $max;
            }
        }

        if(!$change) {
            return $ordinal_of;
        }
    }

    die 'Circular dependency found';
}

sub dot_graph {
    my ($self, $dotname) = @_;
    my @names = keys %{$self->elements};

    open(my $dot_f, '>', $dotname) 
    || die "Could not open '$dotname': $!";

    print { $dot_f } "digraph {\n";

    print { $dot_f } "node [shape=record];\n";

    for my $name (@names) {
        my $e = $self->elements->{$name};
        my $w = $e->{widget};
        my $v = $w->version->normal;

        my $n = $name;
        $n =~ s/[^A-z0-9]//g;

        print { $dot_f } qq($n [label="$name&#92;n$v"];\n);
    }

    for my $name (@names) {
        my @deps;

        my $e = $self->elements->{$name};
        my $w = $e->{widget};

        if($w->dependencies) {
            push @deps, keys %{$w->dependencies};
        }

        if($w->source->dependencies) {
            push @deps, keys %{$w->source->dependencies};
        }

        my $n = $name;
        $n =~ s/[^A-z0-9]//g;

        if(@deps) {
            for my $dep (@deps) {
                my $d = $dep;
                $d =~ s/[^A-z0-9]//g;

                print { $dot_f } qq(\t"$d"->"$n";\n);
            }
        }
    }

    print { $dot_f } "}\n";
    close $dot_f;
}

sub to_makeflow {
    my ($self, $dir, $dag_name, $builder_exec, $local_database, $cores) = @_;

    $self->trimmed_database(catfile($dir,$local_database));

    my $makeflow_name = $dag_name;

    open(my $mflow_f, '>', catfile($dir,$makeflow_name)) 
    || die "Could not open '$dir/$makeflow_name': $!";

    print { $mflow_f } ".MAKEFLOW CATEGORY builds\n";
    print { $mflow_f } ".MAKEFLOW CORES    $cores\n";
    print { $mflow_f } ".MAKEFLOW MEMORY   @{[$cores * 512]}\n";
    print { $mflow_f } ".MAKEFLOW DISK     20000\n";    # 20 GB of disk
    print { $mflow_f } "\n\n";

    my $bag    = $self->bag;
    my $root   = $bag->root_dir;
    my $target = catfile($bag->root_dir, $bag->target);

    my $home   = $bag->home_dir;
    $home      =~ s/^\Q$root/\$(ROOT_DIR)/;

    print { $mflow_f } "RECIPES  = $local_database\n";
    print { $mflow_f } "ROOT_DIR = $root\n";
    print { $mflow_f } "TRGT_DIR = \$(ROOT_DIR)/@{[$bag->target]}\n";
    print { $mflow_f } "HOME_DIR = $home\n";
    print { $mflow_f } "DIST_DIR = " . $bag->files_dir  . "\n";
    print { $mflow_f } "REPO     = " . $bag->repository . "\n";
    print { $mflow_f } "OPTIONS  = --make-jobs \$(CORES) --no-run\n\n";

    print { $mflow_f } "RIBBON   = .VC3_DEPENDENCY_BUILD\n\n";

    print { $mflow_f } "\n";
    print { $mflow_f } "BUILD_COMMAND  = ./$builder_exec --database \$(RECIPES) --install \$(ROOT_DIR) --home \$(HOME_DIR) --distfiles \$(DIST_DIR) --repository \$(REPO) \$(OPTIONS) --ignore-locks\n";

    print { $mflow_f } "\n\n";
    
    my @names = keys %{$self->elements};
    for my $name (@names) {
        my @deps;

        my $e = $self->elements->{$name};
        my $w = $e->{widget};

        if($w->dependencies) {
            push @deps, keys %{$w->dependencies};
        }

        if($w->source && $w->source->dependencies) {
            push @deps, keys %{$w->source->dependencies};
        }

        my @inputs;
        for my $d (@deps) {
            my $rname = $self->elements->{$d}->{widget}->ribbon->{filename};

            $rname =~ s/.VC3_DEPENDENCY_BUILD$/\$(RIBBON)/;
            $rname =~ s/^\Q$target/\$(TRGT_DIR)/;

            push @inputs, $rname;
        }

        my $output = $w->ribbon->{filename};
        $output =~ s/.VC3_DEPENDENCY_BUILD$/\$(RIBBON)/;
        $output =~ s/^\Q$target/\$(TRGT_DIR)/;

        print { $mflow_f } "$output: $builder_exec $local_database @inputs\n";

        print { $mflow_f } "\t";

        if(!$w->source || $w->local) {
            print { $mflow_f } "LOCAL "
        }

        print { $mflow_f } "\t\$(BUILD_COMMAND) --require $name\n\n";
    }

    close $mflow_f;
}

sub prestage {
    my ($self) = @_;

    for my $e (values %{$self->elements}) {
        $e->widget->source->get_files();
    }
}

sub trimmed_database {
    my ($self, $filename) = @_;

    my $output = {};

    for my $e (values %{$self->elements}) {
        $output->{$e->widget->package->name} = $e->package->to_hash;
        $ph->{versions} = [ $e->widget->to_hash ];
    }

    open my $f_h, '>', $filename || die "Could not open $filename for writting: $!\n";

    my $json = JSON::Tiny::encode_json($output);

    print { $f_h } $json, "\n";

    close $f_h;
}

sub to_script {
    my ($self, $filename) = @_;

    open my $f_h, '>', $filename || die "Could not open $filename for writting: $!\n";

    for my $w (@{$self->order}) {
        $self->bag->activate_widget_vars($w);
        $self->bag->set_environment_variables($f_h);
        $self->bag->activate_widget($w);
    }

    close $f_h;
}


package version;
sub TO_JSON {
    my ($self) = @_;
    return $self->normal;
}

1;

