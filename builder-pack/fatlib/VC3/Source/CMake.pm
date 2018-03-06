package VC3::Source::CMake;
use base 'VC3::Source::AutoRecipe';
use Carp;

sub autorecipe {
    my ($self) = @_;

    $self->{dependencies}{'cmake'} ||= ['v3.5.0'];

    my $conf = 'cmake -DCMAKE_INSTALL_PREFIX:PATH=${VC3_PREFIX}';
    if($self->options) {
        $conf = join(' ', $conf, $self->options);
    }

    $conf .= ' ..';

    return [ 'mkdir -p build', 'cd build', $conf, 'make', 'make install' ];
}

1;

