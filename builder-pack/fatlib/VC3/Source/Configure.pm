#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source::Configure;
use base 'VC3::Source::AutoRecipe';
use Carp;

sub autorecipe {
    my ($self) = @_;

    my $conf = './configure --prefix ${VC3_PREFIX}';

    if($self->options) {
        $conf = join(' ', $conf, $self->options);
    }

    return [ $conf, 'make', 'make install' ];
}

1;

