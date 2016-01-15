#!/usr/bin/env php
<?php

$tally = [
	'apertium-all-dev' => [
		'total' => 0,
		'linux' => 0,
		'win' => 0,
		'osx' => 0,
		],
	];
$pkgs = glob('/home/apertium/public_html/apt/nightly/pool/main/*/*', GLOB_ONLYDIR);
foreach ($pkgs as $k => $pkg) {
	$pkgs[$k] = basename($pkg);
	echo "pkg $pkg\n";
	$tally[$pkg] = [
		'total' => 0,
		'linux' => 0,
		'win' => 0,
		'osx' => 0,
		];
}

$pattern = implode('|', $pkgs);

$logs = glob('/var/log/apache2/apertium-access.log');
foreach ($logs as $log) {
	$fh = null;
	if (strpos($log, '.gz') !== false) {
		echo "gzip $log\n";
		$fh = fopen('compress.zlib://'.$log, 'rb');
	}
	else {
		echo "normal $log\n";
		$fh = fopen($log, 'rb');
	}

	while ($line = fgets($fh)) {
		// 208.80.155.255 - - [11/Jan/2016:06:49:03 +0000] "GET /apt/nightly/dists/trusty/main/i18n/Translation-en.bz2 HTTP/1.1" 404 498 "-" "Debian APT-HTTP/1.3 (1.0.1ubuntu2)"
		if (preg_match('~\[([^]]+)\].+?"GET .+?/(apertium-all-dev)\..+?" 200 ~', $line, $m) || preg_match('~\[([^]]+)\].+?"GET .+?/('.$pattern.')[-_](\d|latest).+?" 200 ~', $line, $m)) {
			$m[1] = date('Y-W', strtotime($m[1]));
			echo "{$m[1]} {$m[2]}\n";

			$os = 'linux';
			if (strpos($line, ' /win32/') !== false) {
				$os = 'win';
			}
			else if (strpos($line, ' /osx/') !== false) {
				$os = 'osx';
			}

			$ps = [$m[2]];
			/*
			if ($m[2] === 'apertium-all-dev') {
				$ps = ['lttoolbox', 'apertium', 'apertium-lex-tools', 'hfst', 'hfst-ospell', 'cg3ide', 'cg3', 'trie-tools'];
			}
			//*/

			foreach ($ps as $p) {
				++$tally[$p]['total'];
				++$tally[$p][$os];
			}
		}
	}

	fclose($fh);
}

echo var_export($tally, true), "\n";
