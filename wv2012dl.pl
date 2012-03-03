#!/usr/bin/perl

# Программа для сохранения видеотрансляции выборов Президента в 2012 году
# на диск, в оригинальном виде (как отдельные файлы).

# Принимает в качестве параметра адрес трансляции (или запрашивает его,
# если он не передан в качестве параметра), и сохраняет файлы трансляции
# в текущий каталог.

# Copyright Alexander S. Kharitonov <askh@askh.ru>, 2012

use strict;
use warnings;
use encoding 'utf8';

require LWP::UserAgent;

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

sub create_file_name($$)
{
    my($time, $number) = @_;
    return sprintf("%010d-%04d.mpg", $time, $number);
}

my $MAX_NET_ERRORS = 10;

my %prev_urls;

my $time = time();
my $number = 0;
my $net_err_count = 0;

my $m3u8_url = $ARGV[0];
if(!defined $m3u8_url) {
    print "URL: ";
    $m3u8_url = <STDIN>;
    chomp $m3u8_url;
}

my $server;
if($m3u8_url !~ m[^(https?://[^/]+)/]) {
    print "Wrong url: $m3u8_url\n";
} else {
    $server = $1;
}

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

while(1) {
    my $m3u8_resp = $ua->get($m3u8_url);
    if(!$m3u8_resp->is_success) {
        ++$net_err_count;
        if($net_err_count == $MAX_NET_ERRORS) {
            print "Network error: " . $m3u8_resp->status_line . "\n";
            exit 1;
        }
        next;
    }
    my $m3u8_data = $m3u8_resp->content;
    my $m3u8 = parse_m3u8($m3u8_data);
    if(!$m3u8) {
        print "Wrong M3U8 data: $m3u8_data";
        exit 1;
    }
    print "M3U8 file Ok\n";
    my(@urls) = @{$m3u8->{data}};
    my @download_urls;
    my %new_urls = map { $_ => 1 } @urls;
    foreach my $url (reverse @urls) {
        if($prev_urls{$url}) { last; }
        unshift @download_urls, $url;
    }
    %prev_urls = %new_urls;

    my $err_video = 0;
    my $video_resp;
    foreach my $url (@download_urls) {
        my $video_url = "$server$url";
        print "Downloading video $video_url... ";
        $video_resp = $ua->get($video_url);
        if(!$video_resp->is_success) {
            $err_video = 1;
            print "Fail\n";
            next;
        }
        print "Ok\n";
        $err_video = 0;
        my $time1 = time();
        if($time1 != $time) {
            $time = $time1;
            $number = 0;
        }
        my $file_name = create_file_name($time, $number++);
        open(FILE, ">$file_name") || die "Can't create file: $file_name";
        binmode(FILE);
        print FILE $video_resp->content;
        close(FILE);
    }
    if($err_video) {
        ++$net_err_count;
        if($net_err_count == $MAX_NET_ERRORS) {
            print "Network error: " . $video_resp->status_line . "\n";
            exit 1;
        }
    }
    my $sleep_time = $m3u8->{target_duration} - 1;
    if($sleep_time < 0) { $sleep_time = 0; }
    sleep($sleep_time);
}
