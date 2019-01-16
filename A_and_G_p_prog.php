#!/usr/bin/env php
<?php

$options = getopt('dn');
$today  = isset($options['d']) ? true : false; // 今日のみ
$nowona = isset($options['n']) ? true : false; // 今のみ
//var_dump($options);
//die();

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

if ($nowona) {
    $today = true;
}
if ($today) {
    $now_time = time();
    $today_start_time = strtotime(date('Ymd'));
    $today_end_time = $today_start_time + (24 * 60 * 60);
}

if ($nowona || $today) {
    $dw = date('w');
    $from_dw = $dw;
    $to_dw   = $dw;
} else {
    $from_dw = 1;
    $to_dw   = 7;
}
for ($td = $from_dw; $td <= $to_dw; $td++ ) {

    $day = $xpath->query(".//thead/tr/td[$td]", $table)->item(0)->nodeValue;
    //echo _trim($day), PHP_EOL;

    if ($nowona) {
      $h_min = date('G');
      $h_min = $h_min * 60 - 370;
      $to_min   = $h_min;
      $from_min = $to_min + 70;
    } else {
      $to_min   = 0;
      $from_min = 1440;
    }
    for($tr = $to_min; $tr < $from_min; $tr++ ) {
        $h         = $xpath->query(".//tbody/tr[$tr]/th", $table)->item(0)->nodeValue;
        $throwspan = $xpath->query(".//tbody/tr[$tr]/th[$td]/@rowspan", $table)->item(0)->nodeValue;
        $lengthmin = $xpath->query(".//tbody/tr[$tr]/td[$td]/@rowspan", $table)->item(0)->nodeValue;
        $bg        = $xpath->query(".//tbody/tr[$tr]/td[$td]/@class", $table)->item(0)->nodeValue;
        $time      = $xpath->query(".//tbody/tr[$tr]/td[$td]/div[@class=\"time\"]", $table)->item(0)->nodeValue;
        $prog      = $xpath->query(".//tbody/tr[$tr]/td[$td]/div[@class=\"title-p\"]", $table)->item(0)->nodeValue;
        $rp        = $xpath->query(".//tbody/tr[$tr]/td[$td]/div[@class=\"rp\"]", $table)->item(0)->nodeValue;
        if (_trim($prog)) {
            $start = _start($day, $time);
            $end   = _end($day, $time, $lengthmin);
            $sec   = _m2s($lengthmin);
            $bgStr = _bg($bg);
            $time = substr(_trim($time), 0, 5);
            $start_time = strtotime($start[0]);
            $end_time   = strtotime($end[0]);
            //echo sprintf("%4d", $tr), ' ';
            if ($nowona || $today) {
                if ($nowona &&
                    ($start_time <= $now_time &&
                     $end_time   >= $now_time)) {
                    showProgram($start, $end, $sec, $bgStr, $prog, $rp);
                }
                if ($today && !$nowona &&
                    ($today_start_time <= $start_time &&
                     $today_end_time   >= $start_time)) {
                    showProgram($start, $end, $sec, $bgStr, $prog, $rp);
                }
            } else {
                showProgram($start, $end, $sec, $bgStr, $prog, $rp);
            }
        }
    }
    echo PHP_EOL;
}

function showProgram($start, $end, $sec, $bgStr, $prog, $rp)
{
    echo $start[0], ' ', $end[0], ' ', $start[1], ' ', $end[1], ' ', sprintf("%4d", $sec), ' ',  $bgStr, ' ',  _trim($prog, true), '(', _trim($rp), ')',  PHP_EOL;
}

function _trim($str, $slash = false)
{
    $str = mb_convert_kana($str, 'sanrK');
    $str = trim($str);
    $str = preg_replace('/[\n\r\t]/', '', $str);
    $str = preg_replace('/\s{2,}/', '', $str);

    $patterns     = array('/\?/', '/!/', '/\*/');
    $replacements = array('？'  , '！' , '＊');
    if ($slash) {
      $patterns[]     = '/\//';
      $replacements[] = '／';
    }
    $str = preg_replace($patterns, $replacements, $str);

    return $str;
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

