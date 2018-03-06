package VC3::Source::Tarball;
use base 'VC3::Source::Generic';
use Carp;

sub new {
    my ($class, $widget, $json_description) = @_;

    my $self = VC3::Source::Generic->new($widget, $json_description);

    unless($self->files) {
        croak "For type 'tarball', at least one file should be defined in the files list, and the first file in the list should be a tarball.";
    }

    $self = bless $self, $class;

    return $self;
}

sub prepare_files  {
    my ($self, $build_dir) = @_;

    # first file in $self->files is the tarball, by convention.
    my $tarball = @{$self->files}[0];
    $tarball = $self->file_absolute($tarball);

    system(qq/tar -C ${build_dir} --strip-components=1 -xpf ${tarball}/);
    die "Could not expand tarball $tarball.\n" if $?;

    # link in the rest of the input files.
    $self->SUPER::prepare_files($build_dir);
}

1;

