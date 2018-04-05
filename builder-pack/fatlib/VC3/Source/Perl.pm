#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source::Perl;
use base 'VC3::Source::Generic';
use Carp;

sub new {
    my ($class, $widget, $json_description) = @_;

    unless($json_description->{recipe}) {
        my @steps;
        push @steps, "cpanm --notest --mirror \${VC3_MODULES_PERL_LOCAL_CPAN}/perl --mirror-only " . $json_description->{files}->[0];
        $json_description->{recipe} = \@steps;
    }

    my $self = $class->SUPER::new($widget, $json_description);

    unless($self->files) {
        croak "For type 'perl', at least one file should be defined in the files list.";
    }

    unless($self->dependencies) {
        $self->dependencies({});
    }

    $self->{dependencies}{'perl-cpanminus'} ||= [];

    return $self;
}

sub prepare_files  {
    my ($self, $build_dir) = @_;

    # do nothing
    return;
}

sub get_file {
    my ($self) = @_;

    # do nothing
    return;
}

1;

