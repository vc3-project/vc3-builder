package VC3::Source::Generic;
use Carp;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec::Functions qw/catfile rel2abs/;
use HTTP::Tiny;
use POSIX ":sys_wait_h";
use parent;

sub new {
    my ($class, $widget, $json_description) = @_;

    my $self = bless {}, $class;

    $self->widget($widget);
    $self->recipe($json_description->{recipe});
    $self->files($json_description->{files});
    $self->msg_manual_requirement($json_description->{'msg-manual-requirement'});
    $self->dependencies($json_description->{dependencies});
    $self->prerequisites($json_description->{prerequisites});

    $self->type($json_description->{type} || 'generic');

    return $self;
}

sub to_hash {
    my ($self) = @_;

    $sh->{type}          = $self->type;
    $sh->{recipe}        = $self->recipe;
    $sh->{files}         = $self->files;
    $sh->{dependencies}  = $self->dependencies;
    $sh->{prerequisites} = $self->prerequisites;
    $sh->{options}       = $self->options;
    $sh->{'msg-manual-requirement'} = $self->msg_manual_requirement;

    for my $k (keys %{$sh}) {
        unless(defined $sh->{$k}) {
            delete $sh->{$k};
        }
    }

    return $sh;
}

sub type {
    my ($self, $new_type) = @_;

    $self->{type} = $new_type if($new_type);

    return $self->{type};
}

sub widget {
    my ($self, $new_widget) = @_;

    $self->{widget} = $new_widget if($new_widget);

    croak 'No argument given'
    unless($self->{widget}); 

    return $self->{widget};
}

sub bag {
    my ($self) = @_;

    return $self->widget->package->bag;
}

sub recipe {
    my ($self, $new_recipe) = @_;

    $self->{recipe} = $new_recipe if($new_recipe);

    unless($self->{recipe}) {
        $self->{recipe} = ['echo "no explicit recipe given"'];
    }

    return $self->{recipe};
}

sub files {
    my ($self, $new_files) = @_;

    $self->{files} = $new_files if($new_files);

    unless($self->{files}) {
        $self->{files} = [];
    }

    return $self->{files};
}

sub msg_manual_requirement {
    my ($self, $new_message) = @_;

    if($new_message) {
        $self->{msg_manual_requirement} = $new_message;
    }

    return $self->{msg_manual_requirement};
}

sub check_manual_requirements {
    my ($self, $new_message) = @_;

    # by default return true. Usually packages do not have manual requirements.
    return 1;
}

sub file_absolute {
    my ($self, $file) = @_;
    return rel2abs(catfile($self->bag->files_dir, $file));
}

sub dependencies {
    my ($self, $new_dependencies) = @_;

    if($new_dependencies) {
        $self->{dependencies} = {};

        for my $name (keys %{$new_dependencies}) {
            my $versions = $new_dependencies->{$name};
            my ($min_version, $max_version) = @{$versions};

            if($min_version) {
                $min_version = version->declare($min_version);
            }

            if($max_version) {
                $max_version = version->declare($max_version);

                my $num = $max_version->numify();
                my $fix = ($num * 1000000) % 1000;
                $num   += 0.000999 unless($fix);
                $max_version = version->declare($num);

                unless($min_version) {
                    $min_version = version->declare('v0.0.0');
                }
            }

            $self->{dependencies}{$name} = [];

            if($min_version) {
                push @{$self->{dependencies}{$name}}, $min_version;
            }

            if($max_version) {
                push @{$self->{dependencies}{$name}}, $max_version;
            }
        }
    }

    return $self->{dependencies};
}

sub prerequisites {
    my ($self, $new_prerequisites) = @_;

    $self->{prerequisites} = $new_prerequisites if($new_prerequisites);

    return $self->{prerequisites};
}

sub check_prerequisites {
    my ($self) = @_;

    # by default return true. Usually packages do not have prerequisites.
    unless($self->prerequisites()) {
        return 0;
    }

    my @steps = @{$self->prerequisites};

    my ($pid, $pre_in) = $self->widget->package->bag->shell();

    print { $pre_in } "exec 1>> /dev/null\n";
    print { $pre_in } "exec 2>&1\n";
    print { $pre_in } "set -ex\n";


    # add shifting to tmp directory as the first step.
    unshift @steps, 'cd ' . $self->bag->tmp_dir;

    # add exiting cleanly from shell as a last step.
    push @steps, 'exit 0';

    for my $step (@steps) {
        print { $pre_in } "$step\n";
    }

    my $exit_status = -1;
    eval { close $pre_in; $exit_status = $? };

    if(!$@ && WIFEXITED($exit_status) && (WEXITSTATUS($exit_status) == 0)) {
        return 0;
    } else {
        return -1;
    }
}

sub say {
    my $self = shift @_;

    return $self->widget->say(@_);
}

sub get_file {
    my ($self, $file) = @_;

    unless(-f $self->file_absolute($file)) {
        $self->say("Downloading '" . $file . "' from " . $self->bag->repository);

        my $ff = HTTP::Tiny->new();

        my $url    = $self->bag->repository . '/' . $file;
        my $output = catfile($self->bag->files_dir,  $file);

        my $retries = 5;
        my $sleep_before_retry = 5; # seconds
        my $response;

        for my $i (1..$retries) {
            $response = $ff->mirror($url, $output);

            return if $response->{success};

            # 304 means file did not change from the last time we downloaded it
            return if $response->{status} == 304;

            # retries:
            # 408 is request timeout
            # 503 is service unavailable
            # 504 is a gatewat timeout
            # 524 is a cloudflare timeout
            # 599 is an internal exception of HTTP::Tiny, which may be a timeout too.

            if( grep { $response->{status} == $_ } (408,503,504,524,599) ) {
                print "Could not download '" . $file . "':\n" . "$response->{status}: $response->{reason}\n";
                print "$response->{content}\n" if $response->{content};
                print "Retrying @{[$retries - $i]} more time(s)\n"; 

                VC3::Builder::select_sleep($sleep_before_retry);

                next;
            }

            die "Could not download '" . $file . "':\n" . "$response->{status} $response->{reason}";
        }
    }
}

sub get_files {
    my ($self) = @_;

    my $files = $self->files;

    for my $file (@{$files}) {
        $self->get_file($file);
    }
}

sub prepare_files {
    my ($self, $build_dir) = @_;

    for my $file (@{$self->files}) {
        symlink($self->file_absolute($file), catfile($build_dir, basename($file)))
        || die "Could not link '" . $file . "' to build directory.\n";
    }
}


sub prepare_recipe_sandbox {
    my ($self) = @_;


    my $no_erase = $self->isa('VC3::Source::System');

    my $result = $self->widget->prepare_recipe_sandbox($self, $no_erase);

    if($result == 0) {
        return 0;
    }

    # download to $vc3_distfiles the ingredient (i.e., input files) if missing.
    $self->get_files();

    # if generic, copy all files to build directory.
    # if tarball, expand first file to build directory, and copy the rest of
    # the files to build directory.
    $self->prepare_files($self->widget->build_dir);

    return 1;
}

sub cleanup_recipe_sandbox {
    my ($self, $result) = @_;
    return $self->widget->cleanup_recipe_sandbox($result);
}


sub execute_recipe {
    my ($self, $force_rebuild, $ignore_locks) = @_;

    my $result = 1;

    unless($ignore_locks) {
        $self->widget->ribbon->set_lock();
    }

    eval {
        my $state = $self->widget->ribbon->state;
        if($state eq 'DONE' && !$force_rebuild && !$self->widget->phony) {
            $result = 0;
        } else {
            $self->say("preparing '" . $self->widget->package->name . "' for " . $self->widget->package->bag->target);
            if($self->widget->package->bag->dry_run) {
                $result = 0;
            } else {
                $self->prepare_recipe_sandbox();
                $result = $self->execute_recipe_unlocked();
                $self->cleanup_recipe_sandbox($result);
            }
        }
    };

    my $error_msg = $@;

    unless($ignore_locks) {
        $self->widget->ribbon->release_lock();
    }

    if($error_msg) {
        die $error_msg;
    }

    return $result;
}

sub execute_recipe_unlocked {
    my ($self) = @_;

    unless($self->isa('VC3::Source::System')) {
        $self->widget->ribbon->commit('PROCESSING');
    }

    my $result = -1;
    my ($pid, $build_in) = $self->setup_build_shell();

    my @steps = @{$self->recipe};

    # add shifting to build directory as the first step.
    unshift @steps, 'cd ' . $self->widget->build_dir;

    # add exiting cleanly from shell as a last step.
    push @steps, 'exit 0';

    $self->say("details: " .  $self->widget->build_log);

    for my $step (@steps) {
        print { $build_in } "$step\n";
    }

    my $status = -1;
    eval { close $build_in; $status = $? };
    if($@) {
        carp $@;
    }

    $self->widget->{child_pid} = undef;

    if(!$@ && WIFEXITED($status) && (WEXITSTATUS($status) == 0)) {
        $result = 0;
    }

    return $result;
}

sub setup_build_shell {
    my ($self) = @_;
    return $self->widget->setup_build_shell(@{$self->recipe});
}

1;
