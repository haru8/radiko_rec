#!/usr/bin/env php
<?php

$options = getopt('a::s:dnt');
//var_dump($options);
//if (isset($options['a'])) {
//    echo a, PHP_EOL;
//}
//die();

if (isset($options['s'])) {
    $day = isset($options['d']) ? true : false;
    $now = isset($options['n']) ? true : false;
    $ton = isset($options['t']) ? true : false;
    showProgramByStation($options['s'], $day, $now, $ton);
} else if(isset($options['a'])) {
    showStatioByAreaId($options['a']);
} else {
    usage($argv);
}

function showStatioByAreaId($areaId)
{
    if ($areaId == '') {
        $areaId = 13; // TOKYO JAPAN
    }
    $url = 'http://radiko.jp/v2/station/list/JP' . $areaId . '.xml';
    $xml = file_get_contents($url);
    if ($xml === false) {
        return false;
    }
    $stations = new SimpleXMLElement($xml);
    echo '  ', $stations['area_id'], ': ', $stations['area_name'], PHP_EOL;
    echo PHP_EOL;

    foreach ($stations->station as $station) {
        $stationId   = sprintf("%14s", $station->id);
        $stationName = _trim($station->name);
        $stationName = sprintf("%-15s", $stationName);
        echo '  ', $stationId, ': ', $stationName, PHP_EOL;
    }
}

function showProgramByStation($stationId, $day, $now, $ton)
{
    // 今のみ
    $dateTime = '';
    if ($now) {
        $dateTime = date('YmdHis');
        $day = true;
    }
    // 今日のみ
    if ($day) {
        $h = date('G');
        if ($h <= 4) {
            $h = $h + 24;
            $yesterday = strtotime(date('Ymd')) - (60 * 60 * 24);
            $yesterdayTime = date('Ymd', $yesterday);
            $date = $yesterdayTime;
        } else {
            $date = date('Ymd');
        }
    }

    // 都道府県別
    #$url = 'http://radiko.jp/v2/api/program/today?area_id=JP13';

    // 放送局別
    $url = 'http://radiko.jp/v2/api/program/station/weekly?station_id=' . $stationId;
    $xml = file_get_contents($url);
    if ($xml === false) {
        return false;
    }
    $program = new SimpleXMLElement($xml);
    $station = $program->stations->station;

    //echo $station['id'] .': ' . _trim($station->name) . PHP_EOL;
    //echo PHP_EOL;

    $scd = $station->scd;
    foreach ($scd->progs as $progs) {
        $progsDate = (int)$progs->date;
        if ($day || $now) {
            if ($date == $progsDate) {
                showProgram($progs, $dateTime, $ton);
            }
        } else {
            showProgram($progs, $dateTime, $ton);
        }
    }
}

function showProgram($progs, $dateTime, $ton)
{
    if ($dateTime == '') {
        echo "\nDATE: $progs->date" . PHP_EOL;
    }
    foreach ($progs->prog as $prog) {
        $ft    = (int)$prog['ft'];
        $to    = (int)$prog['to'];
        $dur   = sprintf("%5s", $prog['dur']);
        $title = _trim($prog->title);
        $pfm   = _trim($prog->pfm);
        if ($dateTime == '') {
            showRow(array('ft' => $ft, 'to' => $to, 'ftl' => $prog['ftl'], 'tol' => $prog['tol'], 'dur' => $dur, 'title' => $title), $ton);
        } else {
            if ($ft <= $dateTime && $to >= $dateTime) {
                showRow(array('ft' => $ft, 'to' => $to, 'ftl' => $prog['ftl'], 'tol' => $prog['tol'], 'dur' => $dur, 'title' => $title), $ton);
            }
        }
    }
}

function showRow($parm, $ton)
{
    if ($ton) {
        echo $parm['title'];
    } else {
        echo $parm['ft']. ' ' . $parm['to'] . ' ' . $parm['ftl'] . ' ' . $parm['tol'] . ' ' . $parm['dur'] . ' ' . $parm['title'];
    }
    if ($parm['pfm'] != '') {
        echo '(' . $parm['pfm'] . ')';
    }
    echo PHP_EOL;
}

function _trim($str)
{
    $str = mb_convert_kana($str, 'sanrK');
    $str = trim($str);
    $str = preg_replace('/[\n\r\t]/', ' ', $str);
    $str = preg_replace('/\s{2,}/', ' ', $str);

    $patterns     = array('/\?/', '/!/', '/\*/');
    $replacements = array('？'  , '！' , '＊');
    $str = preg_replace($patterns, $replacements, $str);

    return $str;
}

function usage($argv)
{
    echo 'Usage: ' , $argv[0], ' [options]', PHP_EOL;
    echo PHP_EOL;
    echo 'options:', PHP_EOL;
    echo '  -a [area_id] default:13', PHP_EOL;
    echo '  -s station_d [-d, -n]', PHP_EOL;
}

