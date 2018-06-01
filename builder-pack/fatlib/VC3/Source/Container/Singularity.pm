#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source::Container::Singularity;
use base 'VC3::Source::Container';
use Carp;
use File::Copy;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

sub new {
    my ($class, $widget, $json_description) = @_;

    $json_description->{'images-directory'} = 'images/singularity';
    my $self = $class->SUPER::new($widget, $json_description);

    return $self;
}

sub setup_wrapper {
    my ($self, $exe, $builder_args, $mount_map) = @_;

    my @wrapper;
    push @wrapper, $exe;
    push @wrapper, '--require=singularity';
    push @wrapper, '--revar=".*"';
    push @wrapper, '--install='    . $self->widget->package->bag->root_dir;
    push @wrapper, '--home='       . $self->widget->package->bag->home_dir;
    push @wrapper, '--distfiles='  . $self->widget->package->bag->files_dir;
    push @wrapper, '--repository=' . $self->widget->package->bag->repository;

    push @wrapper, '--';

    push @wrapper, 'singularity';
    push @wrapper, 'exec';

    for my $from (keys %{$mount_map}) {
        push @wrapper, ('-B', $from . ':' . $mount_map->{$from});
    }

    push @wrapper, $self->image;

    push @wrapper, @{$builder_args};

    return \@wrapper;
}

1;

