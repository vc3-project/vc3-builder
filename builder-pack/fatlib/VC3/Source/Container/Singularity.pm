package VC3::Source::Singularity;
use base 'VC3::Source::Generic';
use Carp;
use File::Spec::Functions qw/catfile/;

sub new {
    my ($class, $widget, $json_description) = @_;

    if($widget->wrapper) {
        die "Wrapper specified in conflict with '" . $widget->package->name . "'\n";
    }

    my $self = $class->SUPER::new($widget, $json_description);

    $self->image($json_description->{image});
    $self->setup_wrapper();

    unless($self->recipe) {
    }

    unless($self->dependencies) {
        $self->dependencies({});
    }

    $self->{dependencies}{'singularity'} ||= [];
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

    my $image = $self->image;
    unless($image =~ m^://^) {
        $image = catfile($self->widget->package->bag->files_dir, $image);
    }

    my $wrapper = 'singularity';

    if($self->widget->package->bag->{on_terminal}) {
        $wrapper .= ' shell'
    } else {
        $wrapper .= ' exec'
    }

    $wrapper .= ' --home ${VC3_INSTALL_USER_HOME}';
    $wrapper .= " $image";

    $self->widget->wrapper($wrapper);
}

1;

