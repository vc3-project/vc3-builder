package VC3::Source::Binary;
use base 'VC3::Source::Generic';
use Carp;
# Right now, do the same as generic, but ensure we do it locally in parallel builds.

sub new {
    my ($class, $widget, $json_description) = @_;

    $widget->local(1);

    unless($json_description->{recipe}) {
        $json_description->{recipe} = [
            'mkdir -p ${VC3_PREFIX}',
            'for file in $VC3_FILES; do',
            '   tar -C ${VC3_PREFIX} --strip-components=1 -xf $file',
            'done'
        ]
    }

    return $class->SUPER::new($widget, $json_description);
}

1;

