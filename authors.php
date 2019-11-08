#!/usr/bin/env php
<?php
# Copyright (C) 2014-2019, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 3 or later; see http://www.gnu.org/licenses/

# Usage: svn log -q | awk '{print $3 "\t" $5}' | authors.php
# Usage: git log '--date=format:%Y' '--format=format:%ad%x09%aN <%aE>' | authors.php

$map = file_get_contents(__DIR__.'/authors.json');
$map = json_decode($map, true);

$authors = [];

$count = 0;
while ($line = fgets(STDIN)) {
	$user = null;
	$year = 0;

	if (preg_match('@^(\S+)\s(\d+)@u', $line, $m)) {
		$m[1] = mb_strtolower($m[1]);
		if (empty($map[$m[1]])) {
			echo "UNKNOWN: {$m[1]}\n";
			continue;
		}
		$user = $map[$m[1]];
		$year = intval($m[2]);
	}
	else if (preg_match('~^(\d+)\t(.+?)\s+<(.+?@.+?\..+?)>$~u', $line, $m)) {
		$user = "{$m[2]} <{$m[3]}>";
		$m[3] = mb_strtolower($m[3]);
		if (!empty($map[$m[3]])) {
			$user = $map[$m[3]];
		}
		$year = intval($m[1]);
	}
	else if (preg_match('~^(\d+)\t(.+)$~u', $line, $m)) {
		$user = $m[2];
		$m[2] = mb_strtolower($m[2]);
		if (!empty($map[$m[2]])) {
			$user = $map[$m[2]];
		}
		$year = intval($m[1]);
	}
	else {
		continue;
	}
	++$count;

	if (empty($authors[$user])) {
		$authors[$user] = [
			'lo' => $year,
			'hi' => $year,
			'cnt' => 1,
			];
		continue;
	}

	if ($year < $authors[$user]['lo']) {
		$authors[$user]['lo'] = $year;
	}

	if ($year > $authors[$user]['hi']) {
		$authors[$user]['hi'] = $year;
	}

	++$authors[$user]['cnt'];
}

foreach ($authors as $user => $hilo) {
	echo $hilo['lo'];
	if ($hilo['lo'] != $hilo['hi']) {
		echo '-', $hilo['hi'];
	}
	echo ', ', $user;
	//echo ' (', round($hilo['cnt']*100.0/$count), '%)';
	echo "\n";
}
