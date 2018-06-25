#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use warnings;
use strict;

package VC3::Package;
use Carp;
use File::Temp;
use File::Spec::Functions qw/catfile rel2abs/;

use VC3::Widget;

sub new {
    my ($class, $bag, $name, $json_description) = @_;

    my $self = bless {}, $class;

    $self->original_description($json_description);

    $self->bag($bag);
    $self->name($name);
    $self->dependencies($json_description->{dependencies});
    $self->wrapper($json_description->{wrapper});
    $self->prologue($json_description->{prologue});
    $self->options($json_description->{options});
    $self->environment_variables($json_description->{'environment-variables'});
    $self->environment_autovars($json_description->{'environment-autovars'});
    $self->phony($json_description->{phony});

    $json_description->{'type'} ||= 'package';
    $self->type($json_description->{'type'});

    $self->show_in_list($json_description->{'show-in-list'});
    $self->tags($json_description->{'tags'});

    if($json_description->{versions}) {
        $self->widgets($json_description->{versions});
    } else {
        $self->{widgets} = [];
    }

    return $self;
}

sub to_hash {
    my ($self) = @_;

    my $ph = {};

    $ph->{phony}     = $self->phony;
    $ph->{prologue}  = $self->prologue;
    $ph->{wrapper}   = $self->wrapper;
    $ph->{options}   = $self->options;
    $ph->{type}      = $self->type;

    # environment-autovars already included in environment-variables
    # environment-variables already included in widgets
    # dependencies included in widgets
    
    $ph->{'versions'}       = [];

    for my $w (@{$self->widgets}) {
        push @{$ph->{versions}}, $w->to_hash;
    }

    for my $k (keys %{$ph}) {
        unless(defined $ph->{$k}) {
            delete $ph->{$k};
        }
    }

    return $ph;
}


sub widgets {
    my ($self, $new_widgets_spec) = @_;

    if($new_widgets_spec) {
        my @widgets;
        for my $s (@{$new_widgets_spec}) {
            my $w = VC3::Widget->new($self, $s);
            push @widgets, $w if $w;
        }

        $self->{widgets} = \@widgets;
    }

    return $self->{widgets};
}
        

sub name {
    my ($self, $new_name) = @_;

    if($new_name) {
        # names can only contain letters, numbers, - and _.
        my @badchars = ($new_name =~ /([^A-Za-z0-9-_])/g);
        if(@badchars) {
            die "The name '$new_name' containes the following disallowed charactares: " 
            . join ', ', map { "'$_'" } @badchars;
        } else {
            $self->{name} = $new_name if($new_name);
        }
    }

    die 'No name given'
    unless($self->{name}); 

    return $self->{name};
}

sub original_description {
    my ($self, $new_original) = @_;

    $self->{original_description} = $new_original if($new_original);

    return $self->{original_description};
}

sub dependencies {
    my ($self, $new_dependencies) = @_;

    $self->{dependencies} = $new_dependencies if($new_dependencies);

    return $self->{dependencies};
}

sub prologue {
    my ($self, $new_prologue) = @_;

    $self->{prologue} = $new_prologue if($new_prologue);

    return $self->{prologue};
}

sub wrapper {
    my ($self, $new_wrapper) = @_;

    $self->{wrapper} = $new_wrapper if($new_wrapper);

    return $self->{wrapper};
}

sub options {
    my ($self, $new_options) = @_;

    $self->{options} = $new_options if($new_options);

    return $self->{options};
}

sub environment_variables {
    my ($self, $new_vars) = @_;

    $self->{environment_variables} ||= [];

    if($new_vars) {
        unshift @{$self->{environment_variables}}, @{$new_vars};
    }

    return $self->{environment_variables};
}

sub environment_autovars {
    my ($self, $new_autovars) = @_;

    $self->{environment_autovars} = $new_autovars if($new_autovars);

    return $self->{environment_autovars};
}

sub bag {
    my ($self, $new_bag) = @_;

    $self->{bag} = $new_bag if($new_bag);

    croak 'No bag given'
    unless($self->{bag}); 

    return $self->{bag};
}

sub phony {
    my ($self, $new_phony) = @_;

    $self->{phony} = $new_phony if(defined $new_phony);

    return $self->{phony};
}

sub show_in_list {
    my ($self, $new_show) = @_;

    $self->{show_in_list} = $new_show if(defined $new_show);

    return $self->{show_in_list};
}

sub tags {
    my ($self, $new_tags) = @_;

    $self->{tags} = $new_tags if($new_tags);

    return $self->{tags};
}

sub type {
    my ($self, $new_type) = @_;

    $self->{type} = $new_type if($new_type);

    return $self->{type}
}

1;

