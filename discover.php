#!/usr/bin/env php
<?php
# Copyright (C) 2020, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 3 or later; see https://www.gnu.org/licenses/

chdir(__DIR__);

$q = 'query {
	organization(login:"apertium") {
    repositories(privacy:PUBLIC first:100{AFTER}) {
      totalCount
      edges {
        node {
          name
          isArchived
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}';
$p = '';
$t = getenv('GITHUB_OAUTH_TOKEN');
if (empty($t)) {
	$t = file_get_contents('github.token');
}
if (empty($t)) {
	echo "No GITHUB_OAUTH_TOKEN provided!\n";
	exit(1);
}

////////// GIELLATEKNO LANGUAGES

//*
$q = str_replace('apertium', 'giellalt', $q);
$langs = [];

do {
	$query = str_replace('{AFTER}', $p, $q);
	$query = preg_replace('~\n[ \t]+~', "\n", $query);
	$query = json_encode(['query' => $query]);
	$curl = 'curl -H "Authorization: bearer '.$t.'" -X POST -d '.escapeshellarg($query).' https://api.github.com/graphql';
	fprintf(STDERR, "CURL: %s\n", $curl);
	$data = shell_exec($curl);
	$data = json_decode($data, true);

	foreach ($data['data']['organization']['repositories']['edges'] as $r) {
		$n = $r['node']['name'];
		if ($r['node']['isArchived']) {
			fprintf(STDERR, "ARCHIVED: $n\n", $n);
			continue;
		}

		if (preg_match('~^lang-\w{2,3}$~', $n)) {
			fprintf(STDERR, "LANG: $n\n", $n);
			$langs[] = $n;
		}
	}

	$p = ' after:"'.$data['data']['organization']['repositories']['pageInfo']['endCursor'].'"';
	sleep(1);
} while ($data['data']['organization']['repositories']['pageInfo']['hasNextPage']);

sort($langs);
foreach ($langs as $lang) {
	$iso = str_replace('lang-', '', $lang);
	$giella = "giella-$iso";
	if (file_exists("languages/$giella")) {
		continue;
	}

	$cac = trim(shell_exec("wget -nv https://raw.githubusercontent.com/giellalt/$lang/main/configure.ac https://raw.githubusercontent.com/giellalt/$lang/master/configure.ac -O - 2>/dev/null | grep AC_INIT"));
	if (empty($cac)) {
		echo "NO CAC: $lang\n";
		continue;
	}

	$pkgs = file_get_contents('packages.json5');
	$pkgs = str_replace("\n]\n", "\n   [\"languages/$giella\",      \"https://github.com/giellalt/$lang\"],\n]\n", $pkgs);
	file_put_contents('packages.json5', $pkgs);
	echo shell_exec("cp -av templates/giella-qaa/ languages/$giella");
	rename("languages/$giella/debian/giella-qaa.install", "languages/$giella/debian/giella-$iso.install");
	rename("languages/$giella/debian/giella-qaa-speller.install", "languages/$giella/debian/giella-$iso-speller.install");
	echo shell_exec("grep -rl qaa languages/$giella | xargs -rn1 perl -pe 's/qaa/$iso/g;' -i");
}
//*/

////////// APERTIUM LANGUAGES AND PAIRS

//*
$q = str_replace('giellalt', 'apertium', $q);
$p = '';
$langs = [];
$pairs = [];

do {
	$query = str_replace('{AFTER}', $p, $q);
	$query = preg_replace('~\n[ \t]+~', "\n", $query);
	$query = json_encode(['query' => $query]);
	$curl = 'curl -H "Authorization: bearer '.$t.'" -X POST -d '.escapeshellarg($query).' https://api.github.com/graphql';
	fprintf(STDERR, "CURL: %s\n", $curl);
	$data = shell_exec($curl);
	$data = json_decode($data, true);

	foreach ($data['data']['organization']['repositories']['edges'] as $r) {
		$n = $r['node']['name'];
		if ($r['node']['isArchived']) {
			fprintf(STDERR, "ARCHIVED: $n\n", $n);
			continue;
		}

		if (preg_match('~^apertium-\w{2,3}$~', $n) && $n !== 'apertium-all' && $n !== 'apertium-apy' && $n !== 'apertium-get') {
			fprintf(STDERR, "LANG: $n\n", $n);
			$langs[] = $n;
		}
		if (preg_match('~^apertium-\w{2,3}-\w{2,3}$~', $n) && $n !== 'apertium-all-dev') {
			fprintf(STDERR, "PAIR: $n\n", $n);
			$pairs[] = $n;
		}
	}

	$p = ' after:"'.$data['data']['organization']['repositories']['pageInfo']['endCursor'].'"';
	sleep(1);
} while ($data['data']['organization']['repositories']['pageInfo']['hasNextPage']);

sort($langs);
foreach ($langs as $lang) {
	if (file_exists("languages/$lang")) {
		continue;
	}

	$cac = trim(shell_exec("wget -nv https://raw.githubusercontent.com/apertium/$lang/main/configure.ac https://raw.githubusercontent.com/apertium/$lang/master/configure.ac -O - 2>/dev/null | grep AC_INIT"));
	if (empty($cac)) {
		echo "NO CAC: $lang\n";
		continue;
	}

	$pkgs = file_get_contents('packages.json5');
	$pkgs = str_replace("\n]\n", "\n   [\"languages/$lang\"],\n]\n", $pkgs);
	file_put_contents('packages.json5', $pkgs);
	echo shell_exec("cp -av templates/apertium-qaa/ languages/$lang");
	echo shell_exec("./update-control.pl languages/$lang 2>&1");
}

sort($pairs);
foreach ($pairs as $pair) {
	if (file_exists("pairs/$pair")) {
		continue;
	}

	$cac = trim(shell_exec("wget -nv https://raw.githubusercontent.com/apertium/$pair/main/configure.ac https://raw.githubusercontent.com/apertium/$pair/master/configure.ac -O - 2>/dev/null | grep AC_INIT"));
	if (empty($cac)) {
		echo "NO CAC: $pair\n";
		continue;
	}

	$pkgs = file_get_contents('packages.json5');
	$pkgs = str_replace("\n]\n", "\n   [\"pairs/$pair\"],\n]\n", $pkgs);
	file_put_contents('packages.json5', $pkgs);
	echo shell_exec("cp -av templates/apertium-qaa-qbb/ pairs/$pair");
	echo shell_exec("./update-control.pl pairs/$pair 2>&1");
}

chdir(__DIR__.'/languages/');
$es = glob('apertium-*');
foreach ($es as $e) {
	if (!in_array($e, $langs)) {
		echo "MISSING LANG $e\n";
	}
}

chdir(__DIR__.'/pairs/');
$es = glob('apertium-*');
foreach ($es as $e) {
	if (!in_array($e, $pairs)) {
		echo "MISSING PAIR $e\n";
	}
}
//*/
