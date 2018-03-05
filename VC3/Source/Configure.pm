package VC3::Source::Configure;
use base 'VC3::Source::AutoRecipe';
use Carp;

sub autorecipe {
    my ($self) = @_;

    my $conf = './configure --prefix ${VC3_PREFIX}';

    if($self->options) {
        $conf = join(' ', $conf, $self->options);
    }

    return [ $conf, 'make', 'make install' ];
}

1;

