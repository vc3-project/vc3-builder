#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source::AutoRecipe;
use base 'VC3::Source::Tarball';
use Carp;

sub new {
    my ($class, $widget, $json_description) = @_;

    if($json_description->{recipe}) {
        die "Recipe specified when not needed for '" . $widget->package->name . "'\n";
    }

    # dummy recipe, so Tarball does not complain.
    $json_description->{recipe} = ['dummy'];

    my $self = $class->SUPER::new($widget, $json_description);

    $self->preface($json_description->{preface});
    $self->options($json_description->{options});
    $self->postface($json_description->{postface});

    my @steps;
    if($self->preface) {
        push @steps, @{$self->preface};
    }

    push @steps, @{$self->autorecipe};

    if($self->postface) {
        push @steps, @{$self->postface};
    }

    $self->recipe(\@steps);

    return $self;
}

sub to_hash {
    my ($self) = @_;

    my $sh = $self->SUPER::to_hash();
    $sh->{preface}  = $self->preface;
    $sh->{options}  = $self->options;
    $sh->{postface} = $self->postface;

    # automatically computed, so we delete it.
    delete $sh->{recipe};

    for my $k (keys %{$sh}) {
        unless(defined $sh->{$k}) {
            delete $sh->{$k};
        }
    }

    return $sh;
}

sub preface {
    my ($self, $new_preface) = @_;

    $self->{preface} = $new_preface if($new_preface);

    return $self->{preface};
}

sub postface {
    my ($self, $new_postface) = @_;

    $self->{postface} = $new_postface if($new_postface);

    return $self->{postface};
}

sub options {
    my ($self, $new_options) = @_;

    $self->{options} = $new_options if($new_options);

    return $self->{options};
}

1;

