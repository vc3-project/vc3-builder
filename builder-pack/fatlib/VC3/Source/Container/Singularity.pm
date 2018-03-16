package VC3::Source::Container::Singularity;
use base 'VC3::Source::Generic';
use Carp;
use File::Copy;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

sub new {
    my ($class, $widget, $json_description) = @_;

    if($widget->wrapper) {
        die "Wrapper specified in conflict with '" . $widget->package->name . "'\n";
    }

    my $self = $class->SUPER::new($widget, $json_description);

    $self->{prerequisites} ||= [];
    unshift @{$self->{prerequisites}}, 'which singularity';

    unless($self->dependencies) {
        $self->dependencies({});
    }

    $self->{dependencies}{'singularity'} ||= [];

    my $image = $json_description->{image};
    unless($image) {
        die "No image specified for '" . $widget->package->name . "'\n";
    }

    if($image =~ m^://^ or file_name_is_absolute($image)) {
        $self->image($image);
    } else {
        $image = catfile('images', 'singularity', $image);
        $self->image(catfile($self->widget->package->bag->files_dir, $image));
        push @{$self->files}, $image;
    }

    # anything with a singularity source becomes an operating system
    $self->widget->package->operating_system(1);

    return $self;
}

sub to_hash {
    my ($self) = @_;

    my $sh = $self->SUPER::to_hash();
    $sh->{image} = $self->image;

    # wrapper is generated automatically:
    delete $sh->{wrapper};

    return $sh;
}

sub image {
    my ($self, $new_image) = @_;

    $self->{image} = $new_image if($new_image);

    unless($self->{image}) {
        die "Container recipe for '" . $self->widget->package->name . "' did not define an 'image' field.\n";
    }
    
    return $self->{image};
}

sub setup_wrapper {
    my ($self, $builder_args, $payload_args, $mount_map) = @_;

    my $bag = $self->widget->package->bag;
    my ($root, $home, $files, $tmp) = ($bag->root_dir, $bag->home_dir, $bag->files_dir, $bag->tmp_dir);

    push @wrapper, 'singularity';
    push @wrapper, 'exec';

    my $root_target  = $self->add_mount($mount_map, $bag->root_dir,  '/opt/vc3-root');
    my $home_target  = $self->add_mount($mount_map, $bag->home_dir,  '/opt/vc3-home');
    my $files_target = $self->add_mount($mount_map, $bag->files_dir, '/opt/vc3-distfiles');

    for my $from (keys %{$mount_map}) {
        push @wrapper, ('-B', $from . ':' . $mount_map->{$from});
    }

    if($bag->{packages}{singularity}->options) {
        push @wrapper, @{$bag->{packages}{'singularity'}->options};
    }

    push @wrapper, $self->image;

    push @wrapper, catfile($root_target, 'tmp', 'vc3-builder');
    push @wrapper, '--no-os-switch';
    push @wrapper, $self->remove_mount_args(@{$builder_args});
    push @wrapper, ('--install',   $root_target);
    push @wrapper, ('--distfiles', $files_target);
    push @wrapper, ('--home',      $home_target);

    if(scalar @{$payload_args} > 0) {
        push @wrapper, '--';
        push @wrapper, @{$payload_args};
    }

    $self->widget->wrapper(\@wrapper);

    # hack to clean soon:
    my $builder_path = catfile($bag->tmp_dir, 'vc3-builder');
    copy($0, $builder_path);
    chmod 0755, $builder_path;
}

sub prepare_recipe_sandbox {
    my ($self, $builder_args, $payload_args, $mount_map) = @_;

    $self->get_files();
    $self->setup_wrapper($builder_args, $payload_args, $mount_map);
}

sub add_mount {
    my ($self, $mount_map, $from, $default_target) = @_;

    unless($mount_map->{$from}) {
        $mount_map->{$from} = $default_target;
    }

    return $mount_map->{$from};
}

sub remove_mount_args {
    my ($self, @args) = @_;

    my @builder_args;

    my $prev_mount = 0;
    for my $a (@args) {
        if($prev_mount) {
            $prev_mount = 0;
            next;
        }

        if($a =~ m/^--mount/) {
            $prev_mount = 1;
            next;
        }

        if($a =~ m/^--mount=/) {
            next;
        }

        push @builder_args, $a;
    }

    return @builder_args;
}

1;

