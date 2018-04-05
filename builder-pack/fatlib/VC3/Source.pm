#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source;
use Carp;

use VC3::Source::Generic;
use VC3::Source::Configure;
use VC3::Source::CMake;
use VC3::Source::Tarball;
use VC3::Source::ManualDist;
use VC3::Source::Binary;
use VC3::Source::System;
use VC3::Source::Perl;
use VC3::Source::Container::Singularity;
use VC3::Source::Container::Docker;
use VC3::Source::OSNative;

our $class_of = {};

$class_of->{'generic'}             = 'VC3::Source::Generic';
$class_of->{'configure'}           = 'VC3::Source::Configure';
$class_of->{'cmake'}               = 'VC3::Source::CMake';
$class_of->{'tarball'}             = 'VC3::Source::Tarball';
$class_of->{'manual-distribution'} = 'VC3::Source::ManualDist';
$class_of->{'binary'}              = 'VC3::Source::Binary';
$class_of->{'system'}              = 'VC3::Source::System';
$class_of->{'cpan'}                = 'VC3::Source::Perl';
$class_of->{'singularity'}         = 'VC3::Source::Container::Singularity';
$class_of->{'docker'}              = 'VC3::Source::Container::Docker';
$class_of->{'os-native'}           = 'VC3::Source::OSNative';

sub new {
    my ($widget, $source_raw) = @_;

    my $type  = $source_raw->{type} || 'generic';
    my $class = $class_of->{$type};

    unless($class) {
        die "Do not know about source type '" . $source_raw->{type} . "' for '" . $widget->package->name . "'\n";
    }

    return $class->new($widget, $source_raw);
}

1;

