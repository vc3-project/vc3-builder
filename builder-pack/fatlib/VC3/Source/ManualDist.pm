package VC3::Source::ManualDist;
use base 'VC3::Source::Generic';
use Carp;

use File::Spec::Functions qw/rel2abs catfile/;

sub get_file {
    my ($self, $file) = @_;

    unless(-f $self->file_absolute($file)) {
        die "Missing manual or restricted distribution file '$file'.\n";
    }
}

sub file_absolute {
    my ($self, $file) = @_;
    return rel2abs(catfile($self->bag->files_dir, 'manual-distribution', $file));
}

sub check_manual_requirements {
    my ($self) = @_;

    for my $file (@{$self->files}) {
        unless(-f $self->file_absolute($file)) {
            # check failed, return false
            return 0;
        }
    }

    return 1;
}

1;

