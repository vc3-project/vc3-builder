package VC3::Source::Singularity;
use base 'VC3::Source::Generic';
use Carp;
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

    $self->setup_wrapper();

    return $self;
}

sub to_hash {
    my ($self) = @_;

    my $sh = $self->SUPER::to_hash();
    $sh->{image} = $self->image;

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
    my ($self) = @_;

    my @wrapper;
    push @wrapper, 'singularity';
    push @wrapper, 'exec';

    my $bag = $self->widget->package->bag;
    my ($root, $home, $files, $tmp) = ($bag->root_dir, $bag->home_dir, $bag->files_dir, $bag->tmp_dir);

    # this will fail if names above point to the same dir!
    push @wrapper, ('-B', $bag->root_dir  . ':/opt/vc3-root');
    push @wrapper, ('-B', $bag->home_dir  . ':/opt/vc3-home');
    push @wrapper, ('-B', $bag->files_dir . ':/opt/vc3-distfiles');
    push @wrapper, ('-B', $bag->tmp_dir   . ':/opt/vc3-tmp');
    push @wrapper, $self->image;

    $self->widget->wrapper(\@wrapper);
}

1;

