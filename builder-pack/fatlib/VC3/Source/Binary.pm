package VC3::Source::Binary;
use base 'VC3::Source::Generic';
use Carp;
# Right now, do the same as generic, but ensure we do it locally in parallel builds.

sub new {
    my ($class, $widget, $json_description) = @_;

    $widget->local(1);
    return $class->SUPER::new($widget, $json_description);
}

1;

