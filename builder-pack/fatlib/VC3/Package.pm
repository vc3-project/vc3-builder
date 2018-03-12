package VC3::Package;
use Carp;
use File::Temp;
use File::Spec::Functions qw/catfile rel2abs/;

use VC3::Widget;

sub new {
    my ($class, $bag, $name, $json_description) = @_;

    my $self = bless {}, $class;

    $self->bag($bag);
    $self->name($name);
    $self->dependencies($json_description->{dependencies});
    $self->wrapper($json_description->{wrapper});
    $self->prologue($json_description->{prologue});
    $self->environment_variables($json_description->{'environment-variables'});
    $self->environment_autovars($json_description->{'environment-autovars'});
    $self->phony($json_description->{phony});
    $self->operating_system($json_description->{'operating-system'});
    $self->auto_version($json_description->{'auto-version'});

    $self->show_in_list($json_description->{'show-in-list'});
    $self->tags($json_description->{'tags'});

    if($json_description->{versions}) {
        $self->widgets($json_description->{versions});
    } else {
        $self->{widgets} = [];
    }

    return $self;
}

sub widgets {
    my ($self, $new_widgets_spec) = @_;

    if($new_widgets_spec) {
        my @widgets;
        for my $s (@{$new_widgets_spec}) {
            my $w = VC3::Widget->new($self, $s);
            push @widgets, $w if $w;
        }

        $self->{widgets} = \@widgets;
    }

    return $self->{widgets};
}
        

sub name {
    my ($self, $new_name) = @_;

    if($new_name) {
        # names can only contain letters, numbers, - and _.
        my @badchars = ($new_name =~ /([^A-Za-z0-9-_])/g);
        if(@badchars) {
            die "The name '$new_name' containes the following disallowed charactares: " 
            . join ', ', map { "'$_'" } @badchars;
        } else {
            $self->{name} = $new_name if($new_name);
        }
    }

    die 'No name given'
    unless($self->{name}); 

    return $self->{name};
}

sub dependencies {
    my ($self, $new_dependencies) = @_;

    $self->{dependencies} = $new_dependencies if($new_dependencies);

    return $self->{dependencies};
}

sub prologue {
    my ($self, $new_prologue) = @_;

    $self->{prologue} = $new_prologue if($new_prologue);

    return $self->{prologue};
}

sub wrapper {
    my ($self, $new_wrapper) = @_;

    $self->{wrapper} = $new_wrapper if($new_wrapper);

    return $self->{wrapper};
}

sub environment_variables {
    my ($self, $new_vars) = @_;

    $self->{environment_variables} = $new_vars if($new_vars);

    return $self->{environment_variables};
}

sub environment_autovars {
    my ($self, $new_autovars) = @_;

    $self->{environment_autovars} = $new_autovars if($new_autovars);

    return $self->{environment_autovars};
}

sub auto_version {
    my ($self, $new_auto_version) = @_;

    $self->{auto_version} = $new_auto_version if($new_auto_version);

    return $self->{auto_version};
}

sub bag {
    my ($self, $new_bag) = @_;

    $self->{bag} = $new_bag if($new_bag);

    croak 'No bag given'
    unless($self->{bag}); 

    return $self->{bag};
}

sub compute_auto_version {
    my ($self, $root) = @_;

    unless($self->auto_version) {
        die "I don't know how to compute the version of '" . $self->name . "'\n";
    }

    if($root) {
        $self->bag->add_builder_variable('VC3_PREFIX', $root);
    }

    my ($pid, $auto_in) = $self->bag->shell();

    if($root) {
        $self->bag->del_builder_variable('VC3_PREFIX');
    }

    croak "Could not open $shell for auto-version."
    unless $auto_in;

    my $template = catfile($self->bag->tmp_dir, $self->name . 'XXXXXX');
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

    for my $step (@{$self->auto_version}) {
        print { $auto_in } "$step\n";
    }
    print { $auto_in } "exit 0\n";

    my $status = -1;
    eval { close $auto_in; $status = $? };

    if($@) {
        carp $@;
    }

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
        die "Did not produce version information:\n" . join("\n", @lines);
    }

    return $version;
}



sub phony {
    my ($self, $new_phony) = @_;

    $self->{phony} = $new_phony if(defined $new_phony);

    return $self->{phony};
}

sub show_in_list {
    my ($self, $new_show) = @_;

    $self->{show_in_list} = $new_show if(defined $new_show);

    return $self->{show_in_list};
}

sub tags {
    my ($self, $new_tags) = @_;

    $self->{tags} = $new_tags if($new_tags);

    return $self->{tags};
}

sub operating_system {
    my ($self, $new_os) = @_;

    $self->{operating_system} = $new_os if($new_os);

    return $self->{operating_system};
}

1;

