#
# Copyright (C) 2016- The University of Notre Dame
# This software is distributed under the GNU General Public License.
# See the file COPYING for details.
#

use v5.09;
use strict;
use warnings;

package VC3::Ribbon;

use File::Basename; 
use LockFile::Simple qw(lock unlock);
use File::Spec::Functions qw/catfile rel2abs/;

sub new {
    my ($class, $name, $install_dir, $tmpdir, $checksum) = @_;

    my $self = bless {}, $class;

    $self->{filename} = catfile($install_dir, '.VC3_DEPENDENCY_BUILD');
    $self->{lockname} = catfile($tmpdir, $name . '.lock');
    $self->{checksum} = $checksum;

    $self->{lockmgr} = LockFile::Simple->make(-hold => 3600, -autoclean => 1, -max => 99999, -delay => 5, -stale => 1, -wmin => 2,
        -wfunc => sub { LockFile::Simple::core_warn("Waiting for a lock for '$name'. If you think this lock is stale, please remove the file:\n'" . $self->{lockname} . "'\n") }
    );

    return $self;
}

sub commit {
    my ($self, $state) = @_;

    my $ribbon_fh = IO::Handle->new();
    open ($ribbon_fh, '>', $self->{filename});

    my $report = {};
    $report->{state}    = $state;
    $report->{checksum} = $self->{checksum};
    $report->{time}     = time();

    printf { $ribbon_fh } JSON::Tiny::encode_json($report);

    $ribbon_fh->flush();
    $ribbon_fh->sync();

    $ribbon_fh->close();
}

sub set_lock {
    my ($self) = @_;

    # make sure parent directory exists
    File::Path::make_path( dirname($self->{filename}) );

    $self->{lockobj} = $self->{lockmgr}->lock($self->{filename}, $self->{lockname});
}

sub release_lock {
    my ($self) = @_;
    $self->{lockobj}->release();
}

sub state {
    my ($self) = @_;

    my $name = $self->{filename};
    my $state = 'MISSING';

    if(-f $name) {
        open my $ribbon_fh, '<', $name || warn $!;

        if($ribbon_fh) {
            my $contents = do { local($/); <$ribbon_fh> };
            close($ribbon_fh);

            my $report;
            eval { $report = JSON::Tiny::decode_json($contents) };
            if($@) {
                $state = 'MISSING';
            }

            if(!$report->{state}) {
                $state = 'MISSING';
            #} elsif(!$report->{checksum}) {
            #     $state = 'MISSING';
            # } elsif($report->{checksum} ne $self->{checksum}) {
            # $state = 'OUT_OF_DATE';
            } elsif($report->{state} eq 'PROCESSING') {
                $state = 'PROCESSING';
            } else {
                $state = $report->{state};
            }
        }
    }

    return $state;
}

1;

