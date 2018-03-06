package VC3::Source::AutoRecipe;
use base 'VC3::Source::Tarball';
use Carp;

sub new {
    my ($class, $widget, $json_description) = @_;

    if($json_description->{recipe}) {
        die 'Recipe specified when not needed.'
    }

    # dummy recipe, so Tarball does not complain.
    $json_description->{recipe} = ['dummy'];

    my $self = VC3::Source::Tarball->new($widget, $json_description);
    $self = bless $self, $class;

    $self->preface($json_description->{preface});
    $self->options($json_description->{options});
    $self->epilogue($json_description->{epilogue});

    my @steps;
    if($self->preface) {
        push @steps, @{$self->preface};
    }

    push @steps, @{$self->autorecipe};

    if($self->epilogue) {
        push @steps, @{$self->epilogue};
    }

    $self->recipe(\@steps);

    return $self;
}

sub preface {
    my ($self, $new_preface) = @_;

    $self->{preface} = $new_preface if($new_preface);

    return $self->{preface};
}

sub epilogue {
    my ($self, $new_epilogue) = @_;

    $self->{epilogue} = $new_epilogue if($new_epilogue);

    return $self->{epilogue};
}

sub options {
    my ($self, $new_options) = @_;

    $self->{options} = $new_options if($new_options);

    return $self->{options};
}

1;

