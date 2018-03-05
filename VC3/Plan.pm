package VC3::Plan;
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

        if($self->add_widget($widget, $min, $max)) {
            $self->bag->{indent_level}--;
            return 1;
        }
    }

    $self->say("Failure: $name => [@{[$min || '']}, @{[$max || '']}]");
    $self->bag->{indent_level}--;

    return 0;
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
    (:                      # start of min version
    (?<min> [^:]*)
    (:                      # start of max version
    (?<max> [^:]*)
    )?)?
    $
    /x;

    my ($name, $min, $max) = ($+{name}, $+{min}, $+{max});

    if(!$min && $max) {
        $min = 'v0.0.0';
    }

    # turn into version strings
    $min = version->declare($min) if($min);
    $max = version->declare($max) if($max);

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

    $self->say("Try:     " . $widget->name . " => @{[$version->normal]}");

    if($min && $min gt $version || $max && $max lt $version) {
        $self->say("Incorrect version: @{[$version->normal]} => [@{[$self->version_str($min)]},@{[$self->version_str($max)]}]");
        return 0;
    }

    my $saved_state = $self->elements();

    my $p = $self->elements->{$widget->name};
    my $e = $self->refine($widget, $p, $min, $max);

    my $success;
    if($p && !$e) {
        $self->say("conflicting versions: @{[$widget->name]} [@{[ $self->version_str($p->{min}) ]}, @{[ $self->version_str($p->{max})]} <=> [@{[$self->version_str($min)]}, @{[$self->version_str($max)]}]");
        $success = 0;
    } elsif($p && $e) {
        # already in plan, simple refinenment of versions
        $success = 1;
    } elsif(!$e) {
        $success = 0;
        die('bug, this should not happen.');
    } else {

        if($self->add_dependencies($widget->dependencies)) {
            if($widget->sources) {
                my $s = $self->add_sources($widget->sources);
                if($s) {
                    $widget->active_source($s);
                    $success = 1;
                } else {
                    $self->say("could not add any source for: @{[$widget->name, $version]} => [@{[$self->version_str($min)]}, @{[$self->version_str($max)]}]");
                    $success = 0;
                }
            } else {
                $success = 1;
            }
        } else {
            $self->say("could not set dependencies for: @{[$widget->name]} @{[$version->normal]} => [@{[$self->version_str($min)]}, @{[$self->version_str($max)]}]");
            $success = 0;
        }
    }

    if($success) {
        # add new step to plan
        $self->elements->{$widget->name} = $e;
        $self->say("Success: @{[$widget->name]} @{[$e->widget->version->normal]} => [@{[$self->version_str($min)]}, @{[$self->version_str($max)]}]");
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

sub add_sources {
    my ($self, $sources) = @_;

    my $saved_state = $self->elements();
    for my $s (@{$sources}) {

        if($s->isa('VC3::Source::System')) {
            unless($self->bag->{system}{$s->widget->name}) {
                    next if $self->bag->{no_system}{ALL};
                    next if $self->bag->{no_system}{$s->widget->name};
                }
            }

        if($self->add_source($s)) {
            return $s;
        }
        $self->elements($saved_state);
    }

    return undef;
}


sub add_source {
    my ($self, $source) = @_;

    my $exit_status = -1;
    eval { $exit_status = $source->check_prerequisites() };

    if($exit_status) {
        $self->say("Fail-prereq: " . $source->widget->name . '-' . $source->widget->version->normal);
        return 0;
    }

    return $self->add_dependencies($source->dependencies);
}

sub refine {
    my ($self, $widget, $p, $min, $max) = @_;

    if($p) {
        return $p->refine($min, $max);
    } else {
        VC3::Plan::Element->new($widget, $min, $max, undef);
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

            if($w->active_source && $w->active_source->dependencies) {
                push @deps, keys %{$w->active_source->dependencies};
            }

            my $max = $o;
            if(@deps) {
                $max = 1 + List::Util::max( @{$ordinal_of}{@deps} );
            }

            if($max != $o) {
                $change = 1;
                $ordinal_of->{$w->name} = $max;
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

        if($w->active_source && $w->active_source->dependencies) {
            push @deps, keys %{$w->active_source->dependencies};
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

    my $makeflow_name = 'dag';

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
    print { $mflow_f } "REPO     = " . $bat->repository . "\n";
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

        if($w->active_source && $w->active_source->dependencies) {
            push @deps, keys %{$w->active_source->dependencies};
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

        if(!$w->active_source || $w->active_source->local) {
            print { $mflow_f } "LOCAL "
        }

        print { $mflow_f } "\t\$(BUILD_COMMAND) --require $name\n\n";
    }

    close $mflow_f;
}

sub prestage {
    my ($self) = @_;

    for my $e (values %{$self->elements}) {
        my $s = $e->widget->active_source;
        next unless $s;

        $s->get_files();
    }
}

sub trimmed_database {
    my ($self, $filename) = @_;

    my $output = {};

    for my $e (values %{$self->elements}) {
        my $n = {};
        my $w = $e->widget;
        $n->{version} = $w->version->normal;

        if($w->dependencies) {
            $n->{dependencies} = $w->dependencies;
        }

        if($w->wrapper) {
            $n->{wrapper} = $w->wrapper;
        }

        if($w->prologue) {
            $n->{prologue} = $w->prologue;
        }

        if($w->environment_variables) {
            $n->{'environment-variables'} = $w->environment_variables;
        }

        if($w->phony) {
            $n->{phony} = $w->phony;
        }

        if($w->active_source) {
            my $s = $w->active_source;
            my $m = {};

            $m->{type} = $s->{type};

            if($s->isa('VC3::Source::AutoRecipe')) {
                if($s->preface) {
                    $m->{preface} = $s->preface;
                }

                if($s->epilogue) {
                    $m->{epilogue} = $s->epilogue;
                }

                if($s->options) {
                    $m->{options} = $s->options;
                }
            } elsif($s->recipe) {
                $m->{recipe} = $s->recipe;
            }

            if($s->files) {
                $m->{files} = $s->files;
            }

            if($s->msg_manual_requirement) {
                $m->{msg_manual_requirement} = $s->msg_manual_requirement;
            }

            if($s->dependencies) {
                $m->{dependencies} = $s->dependencies;
            }

            if($s->prerequisites) {
                $m->{prerequisites} = $s->prerequisites;
            }

            if($s->local) {
                $m->{local} = $s->local;
            }


            $n->{sources} = [ $m ];
        }

        $output->{$w->name} = [ $n ];
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
        $self->bag->activate_widget($w);
        $self->bag->set_environment_variables($f_h);
    }

    close $f_h;
}


package version;
sub TO_JSON {
    my ($self) = @_;
    return $self->normal;
}

1;

