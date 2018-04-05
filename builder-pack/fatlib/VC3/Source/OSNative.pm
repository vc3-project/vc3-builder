#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source::OSNative;
use base 'VC3::Source::Generic';
use Carp;

sub new {
    my ($class, $widget, $json_description) = @_;

    $widget->local(1);

    unless($json_description->{prerequisites}) {

        unless($json_description->{native}) {
            die "No method to verify native OS provided. Add prerequisites or native field.\n";
        }

        $json_description->{prerequisites} = [
            ": check if native is prefix of target",
            'pref=${VC3_MACHINE_TARGET#' . $json_description->{native} . '}',
            '[ $pref != ${VC3_MACHINE_TARGET} ] || exit 1'
        ];
    }

    my $self = $class->SUPER::new($widget, $json_description);

    return $self;
}


1;

