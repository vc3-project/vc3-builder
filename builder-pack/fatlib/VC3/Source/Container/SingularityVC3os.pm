package VC3::Source::Container::SingularityVC3os;
use base 'VC3::Source::Container::Singularity';
use Carp;
use File::Copy;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

sub setup_wrapper {
    my ($self, $builder_args, $payload_args) = @_;

    my $bag = $self->widget->package->bag;
    my ($root, $home, $files, $tmp) = ($bag->root_dir, $bag->home_dir, $bag->files_dir, $bag->tmp_dir);

    push @wrapper, 'singularity';
    push @wrapper, 'exec';

    # this will fail if names above point to the same dir!
    push @wrapper, ('-B', $bag->root_dir  . ':/opt/vc3-root');
    push @wrapper, ('-B', $bag->home_dir  . ':/opt/vc3-home');
    push @wrapper, ('-B', $bag->files_dir . ':/opt/vc3-distfiles');
    push @wrapper, ('-B', $bag->tmp_dir   . ':/opt/vc3-tmp');

    if($bag->{packages}{singularity}->options) {
        push @wrapper, @{$bag->{packages}{'singularity'}->options};
    }

    push @wrapper, $self->image;

    push @wrapper, '/opt/vc3-tmp/vc3-builder';
    push @wrapper, '--no-os-switch';
    push @wrapper, @{$builder_args};
    push @wrapper, ('--install',   '/opt/vc3-root');
    push @wrapper, ('--distfiles', '/opt/vc3-distfiles');
    push @wrapper, ('--home',      '/opt/vc3-home');

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
    my ($self, $builder_args, $payload_args) = @_;

    $self->get_files();
    $self->setup_wrapper($builder_args, $payload_args);
}

1;



