package VC3::Source::System;
use base 'VC3::Source::Generic';
use Carp;

sub phony {
    my ($self) = @_;

    return 1;
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

