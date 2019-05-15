#!/usr/bin/env perl
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
package Helpers;
use strict;
use warnings;
use utf8;
use Exporter qw(import);
our @EXPORT = qw( trim ltrim_lines file_get_contents file_put_contents replace_in_file );

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
   open FILE, '<:encoding(UTF-8)', $fname or die "Could not open ${fname}: $!\n";
   my $data = <FILE>;
   close FILE;
   return $data;
}

sub file_put_contents {
   my ($fname,$data) = @_;
   open FILE, '>:encoding(UTF-8)', $fname or die "Could not open ${fname}: $!\n";
   print FILE $data;
   close FILE;
}

sub replace_in_file {
   my ($file, $what, $with) = @_;
   open my $in, '<', $file or die $!;
   open my $out, '>', $file.".$$.new" or die $!;
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

1;
