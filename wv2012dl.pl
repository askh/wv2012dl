#!/usr/bin/perl

use strict;
use warnings;
use encoding 'utf8';


sub parse_m3u8($)
{
    my $_ = $_[0];
    my $result = {};
    if($_ !~ /\A#EXTM3U\n/m) { return undef; }
    if(! /^#EXT-X-MEDIA-SEQUENCE:(\d+)\n/m) {
        return undef;
    } else {
        $result->{media_sequence} = $1;
    }
    if(! /^#EXT-X-TARGETDURATION:(\d+)\n/m) {
        return undef;
    } else {
        $result->{target_duration} = $1;
    }
    $result->{data} = [];
    foreach my $url (/^([^ #].*)\n/mg) {
        push @{$result->{data}}, $url;
    }
    return $result;
}


