#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source::CMake;
use base 'VC3::Source::AutoRecipe';
use Carp;

sub autorecipe {
    my ($self) = @_;

    $self->{dependencies}{'cmake'} ||= ['v3.5.0'];

    my $conf = 'cmake -DCMAKE_INSTALL_PREFIX:PATH=${VC3_PREFIX}';
    if($self->options) {
        $conf = join(' ', $conf, $self->options);
    }

    $conf .= ' ..';

    return [ 'mkdir -p build', 'cd build', $conf, 'make', 'make install' ];
}

1;

