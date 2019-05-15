#!/usr/bin/env perl
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/
use utf8;
use strict;
use warnings;
BEGIN {
   $| = 1;
   binmode(STDIN, ':encoding(UTF-8)');
   binmode(STDOUT, ':encoding(UTF-8)');
}
use open qw( :encoding(UTF-8) :std );

use FindBin qw($Bin);
chdir("$Bin/docker") or die "Could not chdir($Bin/docker): $!\n";

# Create or start the .deb caching proxy
my $exists = 0+`docker ps --filter status=running | grep squid-deb-proxy | wc -l`;
if (!$exists) {
   `docker container prune -f`;
   `docker system prune -f`;
   `mkdir -p /opt/squid-deb-cache`;
   print `docker run -d --restart=always --name squid-deb-proxy -v /opt/squid-deb-cache:/cachedir -p 3124:8000 tinodidriksen/squid-deb-proxy 2>&1`;
   if ($?) {
      print "Docker run tinodidriksen/squid-deb-proxy failed!";
      exit $?;
   }
}

# Create the lintian runners
for my $d (qw(debian ubuntu)) {
   my $exists = 0+`docker images -q lintian-$d | wc -l`;
   if (!$exists) {
      print `cat $Bin/docker/Dockerfile.lintian-$d | docker build --pull -t lintian-$d - 2>&1`;
      if ($?) {
         print "Docker build lintian-$d failed!";
         exit $?;
      }
   }
}
