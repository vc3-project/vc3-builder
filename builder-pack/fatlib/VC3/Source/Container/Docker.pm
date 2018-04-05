#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Source::Container::Docker;
use base 'VC3::Source::Container';
use Carp;
use File::Copy;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

sub new {
    my ($class, $widget, $json_description) = @_;

    $json_description->{'images-directory'} = 'images/docker';
    my $self = $class->SUPER::new($widget, $json_description);

    $self->{prerequisites} ||= [];
    unshift @{$self->{prerequisites}}, 'id -Gn 2> /dev/null | grep docker';

    $self->{dependencies} ||= {};
    $self->{dependencies}{'docker'} ||= [];

    $self->drop_priviliges($json_description->{'drop-priviliges'});

    return $self;
}

sub drop_priviliges {
    my ($self, $new_drop_priviliges) = @_;

    if(defined $new_drop_priviliges) {
        $self->{drop_priviliges} = $new_drop_priviliges;
    }

    return $self->{drop_priviliges};
}

sub setup_wrapper {
    my ($self, $builder_args, $mount_map) = @_;

    my $bag = $self->widget->package->bag;

    my @wrapper;
    push @wrapper, 'docker';
    push @wrapper, 'run';

    push @wrapper, '--rm=true';

    # it would be nice to have this one, but we can't because we need to create
    # the user...
    #push @wrapper, '--read-only';

    # for things that need ptrace:
    push @wrapper, ('--security-opt', 'seccomp=unconfined');

    if($bag->{on_terminal}) {
        push @wrapper, ('-i', '-t');
    }

    for my $from (keys %{$mount_map}) {
        push @wrapper, ('--volume', $from . ':' . $mount_map->{$from});
    }

    push @wrapper, ('--tmpfs', '/tmp');

    push @wrapper, ('--workdir', $mount_map->{$bag->home_dir()});

    if($self->drop_priviliges) {
        push @wrapper, ('--entrypoint', '/sbin/run-with-user');
    }

    my $image = $self->image;
    if($image =~ m#^docker://#) {
        $image =~ s#^docker://##;
    } elsif(-f $image) {
        system("docker load -i $image");
    } else {
        die "I don't know how to process '$image'\n";
    }

    push @wrapper, $image;

    # pass first arguments to run-with-user, if needed
    if($self->drop_priviliges) {
        push @wrapper, ($bag->user_uid, $bag->user_gid);
    }

    push @wrapper, @{$builder_args};

    return \@wrapper;
}

1;

