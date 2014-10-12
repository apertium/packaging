#!/usr/bin/env php
<?php
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/

# Usage: svn log -q ? | awk '{print $3 "\t" $5}' | authors.php

$map = file_get_contents(__DIR__.'/authors.json');
$map = json_decode($map, true);

$authors = [];

while ($line = fgets(STDIN)) {
	if (!preg_match('@^(\S+)\s(\d+)@u', $line, $m)) {
		continue;
	}

	if (empty($map[$m[1]])) {
		echo "UNKNOWN: {$m[1]}\n";
		continue;
	}

	$user = $map[$m[1]];
	$year = intval($m[2]);

	if (empty($authors[$user])) {
		$authors[$user] = [
			'lo' => $year,
			'hi' => $year,
			];
		continue;
	}

	if ($year < $authors[$user]['lo']) {
		$authors[$user]['lo'] = $year;
	}

	if ($year > $authors[$user]['hi']) {
		$authors[$user]['hi'] = $year;
	}
}

foreach ($authors as $user => $hilo) {
	echo $hilo['lo'];
	if ($hilo['lo'] != $hilo['hi']) {
		echo '-', $hilo['hi'];
	}
	echo ', ', $user;
	echo "\n";
}
