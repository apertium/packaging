#!/usr/bin/env php
<?php
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/

while ($line = fgets(STDIN)) {
	$line = trim($line);
	if (!preg_match('@^([^/]+)/([^/]+)$@u', $line, $m)) {
		continue;
	}

	$path = $m[1];
	$pkname = $m[2];
	echo "Gitting up $pkname\n";

	$ver = shell_exec('cat '.$path.'/'.$pkname.'/debian/changelog | head -n1');

#hfst (3.8.0~r4029-1) experimental; urgency=low
	if (!preg_match('@^\Q'.$pkname.'\E \(([^)]+)\)@u', $ver, $m)) {
		echo "changelog did not match\n";
		continue;
	}
	$ver = $m[1];

	if (!preg_match('@^[^r]+r(\d+)@', $ver, $m)) {
		echo "version did not match\n";
		continue;
	}

	$rev = $m[1];

	echo "$path/$pkname $ver $rev\n";

	chdir(__DIR__);
	echo shell_exec('./single-dpkg.pl '.$path.'/'.$pkname.' --auto 0 -m "Debian Science Team <debian-science-maintainers@lists.alioth.debian.org>" --rev '.$rev);
	$glob = glob('/tmp/autopkg.*/'.$pkname.'_*.dsc');
	if (empty($glob)) {
		echo "glob did not match\n";
		continue;
	}

	echo shell_exec('rm -rfv /misc/git/'.$pkname);
	echo shell_exec('git init /misc/git/'.$pkname);
	chdir('/misc/git/'.$pkname);
	echo shell_exec('git-import-dsc --pristine-tar /tmp/autopkg.*/*.dsc');
	echo "\n";
}
