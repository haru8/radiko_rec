#!/usr/bin/env php
<?php

$options = getopt('a::s:dntp');
//var_dump($options);
//if (isset($options['a'])) {
//    echo a, PHP_EOL;
//}
//die();

if (isset($options['s'])) {
    $day = isset($options['d']) ? true : false; // 今日のみ
    $now = isset($options['n']) ? true : false; // 今のみ
    $ton = isset($options['t']) ? true : false; // タイトルのみ
    $pon = isset($options['p']) ? true : false; // パーソナリティのみ
    showProgramByStation($options['s'], $day, $now, $ton, $pon);
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

function showProgramByStation($stationId, $day, $now, $ton, $pon)
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
                showProgram($progs, $dateTime, $ton, $pon);
            }
        } else {
            showProgram($progs, $dateTime, $ton, $pon);
        }
    }
}

function showProgram($progs, $dateTime, $ton, $pon)
{
    if ($dateTime == '') {
        echo "\nDATE: $progs->date" . PHP_EOL;
    }
    foreach ($progs->prog as $prog) {
      //var_dump($prog);
      //die();
        $ft    = (int)$prog['ft'];             // 開始(年月日時分秒)
        $to    = (int)$prog['to'];             // 終了(年月日時分秒)
        $dur   = sprintf("%5s", $prog['dur']); // 放送枠(秒)
        $title = _trim($prog->title);          // タイトル
        $pfm   = _trim($prog->pfm);            // パーソナリティ
        $info  = _trim($prog->info);           // info
        if ($dateTime == '') {
            showRow(array('ft'    => $ft,
                          'to'    => $to,
                          'ftl'   => $prog['ftl'],
                          'tol'   => $prog['tol'],
                          'dur'   => $dur,
                          'title' => $title,
                          'pfm'   => $pfm,
                          'info'  => $info),
                    $ton, $pon);
        } else {
            if ($ft <= $dateTime && $to >= $dateTime) {
                showRow(array('ft'    => $ft,
                              'to'    => $to,
                              'ftl'   => $prog['ftl'],
                              'tol'   => $prog['tol'],
                              'dur'   => $dur,
                              'title' => $title,
                              'pfm'   => $pfm,
                              'info'  => $info),
                        $ton, $pon);
            }
        }
    }
}

function showRow($parm, $ton, $pon)
{
    if ($ton && $pon) {
        $program = mb_strcut($parm['title'], 0, 200);
        $pfm     = mb_strcut($parm['pfm'],   0, 200);
        if ($pfm) {
            $program .=  '(' . $pfm . ')';
        }
        echo mb_strcut($program, 0, 200);
        echo PHP_EOL;
    } else if ($ton) {
        $program = mb_strcut($parm['title'], 0, 200);
        echo $program;
        echo PHP_EOL;
    } else if ($pon) {
        $pfm = mb_strcut($parm['pfm'],   0, 200);
        if ($pfm) {
            echo mb_strcut($pfm, 0, 200);
            echo PHP_EOL;
        }
    } else {
        $program = $parm['title'];
        if ($parm['pfm']) {
            $program .=  '(' . $parm['pfm'] . ')';
        }
        $program = mb_strcut($program, 0, 300);
        echo $parm['ft']. ' ' . $parm['to'] . ' ' . $parm['ftl'] . ' ' . $parm['tol'] . ' ' . $parm['dur'] . ' ' . $program;
        echo PHP_EOL;
    }
    //if ($parm['info'] != '') {
    //    echo '(' . $parm['info'] . ')';
    //}
}

function _trim($str)
{
    $str = mb_convert_kana($str, 'sanrK');
    $str = trim($str);
    $str = preg_replace('/[\n\r\t]/', ' ', $str);
    $str = preg_replace('/\s{2,}/', ' ', $str);

    //$str = html_entity_decode($str);

    $patterns     = array('/\?/', '/\*/', '/\\\/', '/\//', '/:/', '/"/', '/\</', '/\>/', '/\|/', '/&nbsp;/', '/&ensp;/', '/&emsp;/', '/&thinsp;/' );
    $replacements = array('？'  , '＊'  , '￥'   , '／'  , '：' , '\'' , '＜'  , '＞'  , '｜', ' ', ' ', ' ', ' ' ) ;
    $str = preg_replace($patterns, $replacements, $str);

    return $str;
}

function usage($argv)
{
    echo 'Usage: ' , $argv[0], ' [options]', PHP_EOL;
    echo PHP_EOL;
    echo 'options:', PHP_EOL;
    echo 'エリアのstation_idを表示:', PHP_EOL;
    echo '-a [area_id] default:13', PHP_EOL;
    echo '  -a 13    エリアを指定', PHP_EOL;
    echo PHP_EOL;
    echo 'station_idのプログラムを表示:', PHP_EOL;
    echo '-s station_id [-d, -n, -t]', PHP_EOL;
    echo '  -s       放送局IDを指定', PHP_EOL;
    echo '  -d       今日のみ表示', PHP_EOL;
    echo '  -n       今のみ表示', PHP_EOL;
    echo '  -t       タイトルのみ表示', PHP_EOL;
    echo '  -p       パーソナリティのみ表示', PHP_EOL;
}

