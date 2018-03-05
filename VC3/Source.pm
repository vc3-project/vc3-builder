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

sub new {
    my ($class, $widget, $source_raw) = @_;

    my $source;

    if($source_raw->{type} eq 'generic') {
        $source = VC3::Source::Generic->new($widget, $source_raw);
    }
    elsif($source_raw->{type} eq 'configure') {
        $source = VC3::Source::Configure->new($widget, $source_raw);
    }
    elsif($source_raw->{type} eq 'cmake') {
        $source = VC3::Source::CMake->new($widget, $source_raw);
    }
    elsif($source_raw->{type} eq 'tarball') {
        $source = VC3::Source::Tarball->new($widget, $source_raw);
    }
    elsif($source_raw->{type} eq 'manual-distribution') {
        $source = VC3::Source::ManualDist->new($widget, $source_raw);
    }
    elsif($source_raw->{type} eq 'binary') {
        $source = VC3::Source::Binary->new($widget, $source_raw);
    }
    elsif($source_raw->{type} eq 'system') {
        $source = VC3::Source::System->new($widget, $source_raw);
    }
    elsif($source_raw->{type} eq 'cpan') {
        $source = VC3::Source::Perl->new($widget, $source_raw);
    }
    else {
        croak "Do not know about source type '" . $source_raw->{type} . "' for '" . $widget->name . "'";
    }

    return $source;
}

1;

