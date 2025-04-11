#!/usr/bin/env perl
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
package Helpers;
use strict;
use warnings;
use utf8;
use Carp::Always;
use autodie qw(:all);
use Exporter qw(import);
our @EXPORT = qw( format_dur trim ltrim_lines file_get_contents file_put_contents replace_in_file run_fail read_control load_packages );

sub format_dur {
   my ($d) = @_;
   my $rv = '';
   if ($d >= 3600) { $rv .= sprintf('%02uh', int($d/3600)); $d -= int($d/3600)*3600; }
   if ($d >= 60) { $rv .= sprintf('%02um', int($d/60)); $d -= int($d/60)*60; }
   $rv .= sprintf('%02us', $d);
   return $rv;
}

sub trim {
   my ($s) = @_;
   $s =~ s/^\s+//g;
   $s =~ s/\s+$//g;
   return $s;
}

sub ltrim_lines {
   my ($s) = @_;
   $s =~ s/[ \t]+\n/\n/g;
   return $s;
}

sub file_get_contents {
   my ($fname) = @_;
   local $/ = undef;
   open FILE, '<:encoding(UTF-8)', $fname;
   my $data = <FILE>;
   close FILE;
   return $data;
}

sub file_put_contents {
   my ($fname,$data) = @_;
   open FILE, '>:encoding(UTF-8)', $fname;
   print FILE $data;
   close FILE;
}

sub replace_in_file {
   my ($file, $what, $with) = @_;
   open my $in, '<', $file;
   open my $out, '>', $file.".$$.new";
   while (<$in>) {
      if (/$what/) {
         $_ = $with."\n";
      }
      print $out $_;
   }
   close $in;
   close $out;
   rename $file.".$$.new", $file;
}

sub run_fail {
   my ($cmd) = @_;
   my $out = `$cmd`;
   if ($?) {
      print STDERR "Failed to execute: $cmd\n";
      exit($?);
   }
   return $out;
}

sub read_control {
   my ($fname) = @_;
   my $control = file_get_contents($fname);
   $control =~ s@,\s*\n\s*@, @gs;
   return $control;
}

sub load_packages {
   use FindBin qw($Bin);
   use JSON;
   my %ps = ('order' => [], 'packages' => {});

   my $pkgs = JSON->new->relaxed->decode(file_get_contents("$Bin/packages.json5"));
   for my $pkg (@{$pkgs}) {
      my ($pkname) = ($pkg->[0] =~ m@([-\w]+)$@);
      push(@{$ps{'order'}}, $pkname);
      $ps{'packages'}{$pkname} = $pkg;
   }

   return %ps;
}

1;
