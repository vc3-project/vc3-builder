use strict;
use warnings;

package VC3::Source::System;
use base 'VC3::Source::Generic';
use Carp;

sub new {
    my ($class, $widget, $json_description) = @_;

    $widget->local(1);

    my $exe = $json_description->{executable};

    if($exe) {
        $json_description->{prerequisites} ||= [];
        unshift @{$json_description->{prerequisites}}, "which $exe";

        unless($json_description->{recipe}) {
            $json_description->{recipe} = [
                "bin=\$(dirname \$(which $exe))",
                "echo VC3_ROOT_SYSTEM: \${bin%%bin}"
            ];
        }

        unless($json_description->{'auto-version'}) {
            $json_description->{'auto-version'} = [
                "echo VC3_VERSION_SYSTEM: \$($exe --version | head -n1 | sed -r -e 's/(^|.*[^0-9.])([0-9]+(\\.[0-9]+){0,2}).*/\\2/')"
            ];
        }
    }

    my $self = $class->SUPER::new($widget, $json_description);

    $self->auto_version($json_description->{'auto-version'});

    return $self;
}

sub auto_version {
    my ($self, $new_auto_version) = @_;

    $self->{auto_version} = $new_auto_version if($new_auto_version);

    return $self->{auto_version};
}

sub execute_recipe_unlocked {
    my ($self) = @_;

    my $output_filename = $self->widget->build_log;

    my $result;
    eval { $result = $self->SUPER::execute_recipe_unlocked(); };

    if($@) {
        die $@;
    } else {
        open(my $f, '<', $output_filename) || die 'Did not produce root directory file';
        my $root;
        while( my $line = <$f>) {
            if($line =~ m/^VC3_ROOT_SYSTEM:\s*(?<root>.*)$/) {
                $root = $+{root};
                chomp($root);
                # update root from widget with the new information:
                $self->widget->root_dir($root);
                last;
            }
        }
        close $f;
        if(!$root) {
            die 'Did not produce root directory information.';
        }
        $root = '' if $root eq '/';
    }

    return $result;
}

1;

