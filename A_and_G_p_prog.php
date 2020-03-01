#!/usr/bin/env php
<?php

$options = getopt('dntph');
$opt = array();
$opt['today']     = isset($options['d']) ? true : false; // 今日のみ
$opt['nowona']    = isset($options['n']) ? true : false; // 今のみ
$opt['titleonly'] = isset($options['t']) ? true : false; // タイトルのみ
$opt['persoonly'] = isset($options['p']) ? true : false; // パーソナリティのみ
$opt['help']      = isset($options['h']) ? true : false; // help

//var_dump($options);
//die();

if ($opt['help']) {
    usage($argv);
    exit(1);
}

$url = 'http://www.agqr.jp/timetable/streaming.html';
$html = file_get_contents($url);
$dom = new DOMDocument('1.0', 'UTF-8');
$html = mb_convert_encoding($html, "HTML-ENTITIES", 'UTF-8');
$dom->preserveWhiteSpace = false;
@$dom->loadHTML($html);
$dom->formatOutput = true;

$xpath = new DOMXPath($dom);
$xpath->registerNamespace("php", "http://php.net/xpath");
$xpath->registerPHPFunctions();

$table = $xpath->query('//table[@class="timetb-ag"]')->item(0);

$nowTime = time();
//$nowTime = $nowTime + ((60 * 60 * 24) * 2) + (60 * 60 * 13);
//echo $nowTime . PHP_EOL;
//echo date('Y/m/d H:i:s', $nowTime) . PHP_EOL;
if ($opt['nowona']) {
    $opt['today'] = true;
}
if ($opt['today']) {
    $h = date('G', $nowTime); // 時。24時間単位。先頭にゼロを付けない。
    if ($h <= 4) {
        $yesterday = strtotime(date('Ymd', $nowTime)) - (60 * 60 * 24);
        $today_start_time = $yesterday;
    } else {
        $today_start_time = strtotime(date('Ymd', $nowTime));
    }
    $now_time = $nowTime;
    $today_end_time = $today_start_time + (24 * 60 * 60) + (4 * 60 * 60);
}

if ($opt['nowona'] || $opt['today']) {
    $dw = date('N', $nowTime); // 曜日。数値。1(月曜日)から 7(日曜日)
    $h  = date('G', $nowTime); // 時。24時間単位。先頭にゼロを付けない。
    if ($h <= 4) {
        $from_dw = $dw - 1;
        $to_dw   = $dw - 1;
    } else {
        $from_dw = $dw;
        $to_dw   = $dw;
    }
} else {
    $from_dw = 1;
    $to_dw   = 7;
}
if ($from_dw == 0) {
    $from_dw = 7;
}
if ($to_dw == 0) {
    $to_dw = 7;
}

$allProgram = array();
$n = 0;
for ($td = $from_dw; $td <= $to_dw; $td++ ) {

    $day = $xpath->query(".//thead/tr/td[$td]", $table)->item(0)->nodeValue;
    //echo _trim($day), PHP_EOL;

    if ($opt['nowona']) {
      $h = date('G', $nowTime);
      if ($h <= 4) {
        $h = $h + 24;
      }
      $h_min = ($h * 60) - 370;
      $to_min   = $h_min;
      $from_min = $to_min + 70;
    } else {
      $to_min   = 0;
      $from_min = 1440;
    }
    for ($tr = $to_min; $tr < $from_min; $tr++ ) {
        $h         = $xpath->query(".//tbody/tr[$tr]/th", $table)->item(0)->nodeValue;
        $throwspan = $xpath->query(".//tbody/tr[$tr]/th[$td]/@rowspan", $table)->item(0)->nodeValue;
        $lengthmin = $xpath->query(".//tbody/tr[$tr]/td[$td]/@rowspan", $table)->item(0)->nodeValue;
        $bg        = $xpath->query(".//tbody/tr[$tr]/td[$td]/@class", $table)->item(0)->nodeValue;
        $time      = $xpath->query(".//tbody/tr[$tr]/td[$td]/div[@class=\"time\"]", $table)->item(0)->nodeValue;
        $prog      = $xpath->query(".//tbody/tr[$tr]/td[$td]/div[@class=\"title-p\"]", $table)->item(0)->nodeValue;
        $rp        = $xpath->query(".//tbody/tr[$tr]/td[$td]/div[@class=\"rp\"]", $table)->item(0)->nodeValue;
        $program   = array('td' => $td, 'tr' => $tr, 'prog' => _trim($prog), 'rp' => _trim($rp));
        if ($program['prog']) {
            $program['start'] = _start($day, $time);
            $program['end']   = _end($day, $time, $lengthmin);
            $program['sec']   = _m2s($lengthmin);
            $program['bgStr'] = _bg($bg);
            $time = substr(_trim($time), 0, 5);
            $start_time = strtotime($program['start'][0]);
            $end_time   = strtotime($program['end'][0]);
            //echo sprintf("%4d", $tr), ' ';
            $allProgram[$start_time] = $program;
            $n++;
        }
    }
}

ksort($allProgram);
foreach ($allProgram as $key => $programVal) {
    $start_time = strtotime($programVal['start'][0]);
    $end_time   = strtotime($programVal['end'][0]);
    if ($opt['nowona'] || $opt['today']) {
        // 今
        if ($opt['nowona'] &&
            ($start_time <= $now_time &&
             $end_time   >= $now_time)) {
            showProgram($programVal, $opt);
            //exit;
        }
        // 今日
        if ($opt['today'] && !$opt['nowona'] &&
            ($today_start_time <= $start_time &&
             $today_end_time   >= $start_time)) {
            showProgram($programVal, $opt);
        }
    } else {
        if (!$opt['nowona'] && !$opt['today']) {
            $h = date('G', $start_time);
            if ($h >= 5 && $h <= 6) {
                echo PHP_EOL;
            }
        }
        showProgram($programVal, $opt);
    }
}

function showProgram($prog, $opt)
{
    if ($opt['titleonly'] && $opt['persoonly']) {
        $program = mb_strimwidth(_trim($prog['prog'], true), 0, 200, '...');
        $rp      = mb_strimwidth(_trim($prog['rp'], true), 0, 200, '...');
        if ($opt['persoonly'] && $rp) {
            $program .= '(' . $prog['bgStr'] . ')';
        }
        if ($rp) {
          $program .= '(' . $rp . ')';
        }
        echo mb_strimwidth($program, 0, 200, '...');
        echo PHP_EOL;
    } else if ($opt['titleonly']) {
        $program = mb_strimwidth(_trim($prog['prog'], true), 0, 200, '...');
        echo $program;
        if (_trim($prog['bgStr'])) {
          echo '(' . $prog['bgStr'] . ')';
        }
        echo PHP_EOL;
    } else if ($opt['persoonly']) {
        $rp      = mb_strimwidth(_trim($prog['rp'], true), 0, 200, '...');
        if ($rp) {
            echo $rp . PHP_EOL ;
        }
    } else {
        $startDay = date('Y/m/d', strtotime($prog['start'][0]));
        echo $startDay, ' ', _weekDay($prog['start'][0]), ' ', $prog['start'][1], ' ', $prog['end'][1], ' ', sprintf("%4d", $prog['sec']), ' ',  $prog['bgStr'], ' ',  _trim($prog['prog'], true);
        if (_trim($prog['rp'], true)) {
            echo '(', $prog['rp'], ')';
        }
        echo PHP_EOL;
    }
}

function _trim($str, $slash = false)
{
    $str = mb_convert_kana($str, 'sanrK');
    $str = trim($str);
    $str = preg_replace('/[\n\r\t]/', '', $str);
    $str = preg_replace('/\s{2,}/', '', $str);

    $patterns     = array('/\?/', '/!/', '/\*/', '/;/', '/"/', '/\|/', '/\</', '/\>/', '/\\\/');
    $replacements = array('？'  , '！' , '＊'  , '；' , '\'' , '｜'  , '＜'  , '＞'  , '￥'   );
    if ($slash) {
      $patterns     = array_merge($patterns,     array('/\//', '/:/'));
      $replacements = array_merge($replacements, array('／'  , '：' ));
    }
    $str = preg_replace($patterns, $replacements, $str);

    return $str;
}

function _weekDay($day)
{
  $dayTime = strtotime($day);
  $weekDay = array( '日', '月', '火', '水', '木', '金', '土');
  return $weekDay[date('w')];
}

function _bg($str)
{
    if (_trim($str) == 'bg-l') {
        $bgStr = '生';
    } else if (_trim($str) == 'bg-f') {
        $bgStr = '初';
    } else if (_trim($str) == 'bg-repeat') {
        $bgStr = '再';
    } else {
        $bgStr = '　';
    }

    return $bgStr;
}

function _start($day, $time)
{
    $day  = _trim($day);
    $day  = substr($day, 0, 5);
    $dayEx = explode('/', $day);

    $time = _trim($time);
    $time = substr($time, 0, 5);
    $timeEx = explode(':', $time);

    $starttime = new DateTime($day);

    if ($timeEx[0] >= 24) {
        $timeEx[0] = $timeEx[0] - 24;
        $starttime->modify("+1 days");
    }
    $starttime->modify("+$timeEx[0] hours $timeEx[1] minutes");

    $YmdHis = $starttime->format('Y/m/d H:i');
    $His    = $starttime->format('H:i');

    return array($YmdHis, $His);
}

function _end($day, $time, $min)
{
    $day  = _trim($day);
    $day  = substr($day, 0, 5);
    $dayEx = explode('/', $day);

    $time = _trim($time);
    $time = substr($time, 0, 5);
    $timeEx = explode(':', $time);

    $min  = _trim($min);

    $endtime = new DateTime($day);

    if ($timeEx[0] >= 24) {
        $timeEx[0] = $timeEx[0] - 24;
        $endtime->modify("+1 days");
    }
    $endtime->modify("+$timeEx[0] hours $timeEx[1] minutes");
    $endtime->modify("+$min minutes");

    $YmdHis = $endtime->format('Y/m/d H:i');
    $His    = $endtime->format('H:i');

    return array($YmdHis, $His);
}

function _m2s($min)
{
    $min  = _trim($min);
    return $min * 60;
}

function usage($argv)
{
    $me = basename($argv[0]);
    echo PHP_EOL;
    echo "Usage: $me [OPTION]" . PHP_EOL;
    echo "  -d: 今日のプログラムみを表示する" . PHP_EOL;
    echo "  -n: 現在放送中のプログラムみを表示する" . PHP_EOL;
    echo "  -t: タイトルのみを表示する"  . PHP_EOL;
    echo "  -p: パーソナリティのみを表示する" . PHP_EOL;
    echo "  -h: help";
}

