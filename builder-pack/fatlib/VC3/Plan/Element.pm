package VC3::Plan::Element;

sub new {
    my ($class, $widget, $min, $max) = @_;

    my $self = bless {}, $class;

    if($min && $max && $min gt $max) {
        die 'Incompatible versions';
    }

    $self->{widget} = $widget;
    $self->{min}    = $min;
    $self->{max}    = $max;

    return $self;
}

sub widget {
    my ($self, $new) = @_;

    if($new) {
        $self->{widget} = $new;;
    }

    return $self->{widget};
}

sub min {
    my ($self, $new) = @_;

    if($new) {
        $self->{min} = $new;
    }

    return $self->{min};
}

sub max {
    my ($self, $new) = @_;

    if($new) {
        $self->{max} = $new;
    }

    return $self->{max};
}

sub refine {
    my ($self, $new_min, $new_max) = @_;

    if($new_min && $self->{max} && $new_min gt $self->{max}) {
        return undef;
    }

    if($new_max && $self->{min} && $new_max lt $self->{min}) {
        return undef;
    }

    my $min = $new_min || $self->{min};
    if($new_min && $self->{min}) {
        $min = $new_min lt $self->{min} ? $new_min : $self->{min};
    }

    my $max = $new_max || $self->{max};
    if($new_max && $self->{max}) {
        $max = $new_max lt $self->{max} ? $new_max : $self->{max};
    }

    if($min && $min gt $self->{widget}->version) { 
        return undef;
    }


    if($max && $max lt $self->{widget}->version) {
        return undef;
    }
        
    return VC3::Plan::Element->new($self->{widget}, $min, $max);
}

1;

