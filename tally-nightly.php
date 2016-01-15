#!/usr/bin/env php
<?php

$pkgs = glob('/home/apertium/public_html/apt/nightly/pool/main/*/*', GLOB_ONLYDIR);
foreach ($pkgs as $k => $pkg) {
	$pkgs[$k] = basename($pkg);
}

$pattern = implode('|', $pkgs);

$tally = [];

$logs = glob('/var/log/apache2/apertium-access.log*');
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
		// 213.37.1.67 - - [11/Jan/2016:13:05:37 +0000] "GET /osx/apertium-simpleton-osx64.zip HTTP/1.1" 200 10203680 "http://apertium.projectjj.com/osx/" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.106 Safari/537.36"
		if (strpos($line, '/stats/') !== false || strpos($line, 'robot') !== false || strpos($line, '/bot ') !== false || strpos($line, '/bot.') !== false || strpos($line, 'Googlebot') !== false || strpos($line, '192.99.34.59') !== false || strpos($line, '2607:5300:60:493b:') !== false) {
			continue;
		}

		if (preg_match('~\[([^]]+)\].+?"GET .+?(?:/|=)(apertium-all-dev)\..+?" 200 ~', $line, $m) || preg_match('~\[([^]]+)\].+?"GET .+?(?:/|=)('.$pattern.')(([-_](\d|latest|osx64))|( H)).+?" 200 ~', $line, $m)) {
			$w = strtotime($m[1]);
			if (empty($w) || empty($m[1]) || empty($m[2])) {
				fprintf(STDERR, "%s", $line);
				continue;
			}
			$w = date('o-W', $w);
			$p = $m[2];

			$os = 'linux';
			if (strpos($line, ' /win32/') !== false) {
				$os = 'win';
			}
			else if (strpos($line, ' /osx/') !== false) {
				$os = 'osx';
			}

			if (empty($tally[$w][$p]['total'])) {
				$tally[$w][$p]['total'] = 0;
			}
			++$tally[$w][$p]['total'];

			if (empty($tally[$w][$p][$os])) {
				$tally[$w][$p][$os] = 0;
			}
			++$tally[$w][$p][$os];
		}
	}

	fclose($fh);
}

$ks = ['total', 'linux', 'win', 'osx'];
$pkgs = [];

foreach ($tally as $w => $ps) {
	ksort($ps);

	$html = <<<XOUT
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<title>Package download stats for week {$w}</title>

<style type="text/css">
tr:nth-child(odd) {
	background-color: #ddd;
}
</style>
</head>
<body>
<h1>Package download stats for week {$w}</h1>
<table>
<thead>
	<tr><th>Package</th><th>Total</th><th>Linux</th><th>Win</th><th>Mac</th></tr>
</thead>
<tfoot>
	<tr><th>Package</th><th>Total</th><th>Linux</th><th>Win</th><th>Mac</th></tr>
</tfoot>
<tbody>
XOUT;
	foreach ($ps as $p => $vals) {
		$html .= '<tr><td>'.htmlspecialchars($p).'</td>';
		foreach ($ks as $k) {
			$val = !empty($vals[$k]) ? $vals[$k] : 0;
			$html .= '<td>'.htmlspecialchars($val).'</td>';
			if (empty($pkgs[$p][$w][$k])) {
				$pkgs[$p][$w][$k] = 0;
			}
			$pkgs[$p][$w][$k] += $val;
		}
		$html .= '</tr>';
	}
	$html .= <<<XOUT
</tbody>
</table>
</body>
</html>

XOUT;

	file_put_contents('/home/apertium/public_html/apt/stats/weekly/'.$w.'.html', $html);
}

foreach ($pkgs as $p => $ws) {
	krsort($ws);

	$html = <<<XOUT
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<title>Download stats for package {$p}</title>

<style type="text/css">
tr:nth-child(odd) {
	background-color: #ddd;
}
</style>
</head>
<body>
<h1>Download stats for package {$p}</h1>
<table>
<thead>
	<tr><th>Week</th><th>Total</th><th>Linux</th><th>Win</th><th>Mac</th></tr>
</thead>
<tfoot>
	<tr><th>Week</th><th>Total</th><th>Linux</th><th>Win</th><th>Mac</th></tr>
</tfoot>
<tbody>
XOUT;
	foreach ($ws as $w => $vals) {
		$html .= '<tr><td>'.htmlspecialchars($w).'</td>';
		foreach ($ks as $k) {
			$val = !empty($vals[$k]) ? $vals[$k] : 0;
			$html .= '<td>'.htmlspecialchars($val).'</td>';
		}
		$html .= '</tr>';
	}
	$html .= <<<XOUT
</tbody>
</table>
</body>
</html>

XOUT;

	file_put_contents('/home/apertium/public_html/apt/stats/'.$p.'.html', $html);
}

shell_exec('chown -R apertium:apertium /home/apertium/public_html/apt/stats');
