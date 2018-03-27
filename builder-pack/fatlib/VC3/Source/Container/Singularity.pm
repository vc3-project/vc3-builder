use strict;
use warnings;

package VC3::Source::Container::Singularity;
use base 'VC3::Source::Container';
use Carp;
use File::Copy;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

sub new {
    my ($class, $widget, $json_description) = @_;

    $json_description->{'images-directory'} = 'images/singularity';
    my $self = $class->SUPER::new($widget, $json_description);

    $self->{prerequisites} ||= [];
    unshift @{$self->{prerequisites}}, 'which singularity';

    $self->{dependencies} ||= {};
    $self->{dependencies}{'singularity'} ||= [];

    return $self;
}

sub setup_wrapper {
    my ($self, $builder_args, $mount_map) = @_;

    my @wrapper;
    push @wrapper, 'singularity';
    push @wrapper, 'exec';

    for my $from (keys %{$mount_map}) {
        push @wrapper, ('-B', $from . ':' . $mount_map->{$from});
    }

    push @wrapper, $self->image;

    push @wrapper, @{$builder_args};

    return \@wrapper;
}

1;

