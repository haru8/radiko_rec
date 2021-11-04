#!/usr/bin/env php
<?php
$url = 'https://www.joqr.co.jp/qr/agdailyprogram/';

$options = getopt('dntph');
$opt = [];
$opt['today']     = isset($options['d']) ? true : false; // 今日のみ
$opt['nowona']    = isset($options['n']) ? true : false; // 今のみ
$opt['titleonly'] = isset($options['t']) ? true : false; // タイトルのみ
$opt['persoonly'] = isset($options['p']) ? true : false; // パーソナリティのみ
$opt['help']      = isset($options['h']) ? true : false; // help

if ($opt['help']) {
  usage($argv);
  exit(1);
}

if ($opt['nowona']) {
  $opt['today'] = true;
  $nowDt = new DateTimeImmutable();
}

$program = getDaily($url);

if (!$opt['today']) {
  $pastDayDt   = new DateTime();
  $futureDayDt = new DateTime();
  $dayYmd = [];
  for($i = 1; $i <= 3; $i++) {
    $pastDayDt->modify("-1 days");
    $dayYmd[] = $pastDayDt->format('Ymd');
    $futureDayDt->modify("+1 days");
    $dayYmd[] = $futureDayDt->format('Ymd');
  }
  sort($dayYmd);

  foreach ($dayYmd as $d) {
    $daily = getDaily($url . '?date=' . $d);
    $program = array_merge($program, $daily);
  }
  $program = sortByKey('startU', SORT_ASC, $program);
}

if ($opt['nowona']) {
  $ret = searchDateTime($program, $nowDt);
  if (count($ret) == 0) {
    $ret = [
      'title'       => '放送休止',
      'personality' => '',
    ];
  }
  $program = [$ret];
}

if ($opt['titleonly'] && $opt['persoonly']) {
  showProgramTitlePersonality($program);
} else if ($opt['titleonly']) {
  showProgramTitleOnly($program);
} else if ($opt['persoonly']) {
  showProgramPersonalityOnly($program);
} else {
  showProgram($program);
}

function getDaily($url)
{
  $dom = new DOMDocument;
  $dom->preserveWhiteSpace = false;
  @$dom->loadHTML(mb_convert_encoding(file_get_contents($url), 'HTML-ENTITIES', 'UTF-8'));

  $xpath = new DOMXPath($dom);

  $date = $xpath->query('//h3[@class="heading_date"]/span[@class="heading_date-text"]')->item(0)->nodeValue;
  $dof  = $xpath->query('//h3[@class="heading_date"]/span[@class="heading_date-text"]/span[@class="heading_date-small"]')->item(0)->nodeValue;
  $date = str_replace($dof, '', $date);
  $date = _trim($date);
  $dt = new DateTimeImmutable($date);

  $dailyProgram = $xpath->query('//article[contains(@class, "dailyProgram-itemBox")]');
  $program = getProgram($xpath, $dailyProgram, $dt);
  $program = sortByKey('startU', SORT_ASC, $program);

  return $program;
}

function getProgram($xpath, $dailyProgram, $dt)
{
  $programs = [];

  foreach ($dailyProgram as $node) {
    $articleClass = $node->getAttribute('class');
    $repeat = false;
    if (strpos($articleClass, 'is-repeat')) {
      $repeat = true;
    }
    $ag = false;
    if (strpos($articleClass, 'ag')) {
      $ag = true;
    }

    $time  = $xpath->query('.//h3[@class="dailyProgram-itemHeaderTime"]', $node)->item(0)->nodeValue;
    $times = explode(' ', _trim($time));
    $s = explode(':', _trim($times[0]));
    $e = explode(':', _trim($times[2]));
    $startDate = $dt->add(new DateInterval('PT' . _trim($s[0]) . 'H' . (_trim($s[1]) == '00' ? '' : _trim($s[1]) . 'M')));
    $endDate   = $dt->add(new DateInterval('PT' . _trim($e[0]) . 'H' . (_trim($e[1]) == '00' ? '' : _trim($e[1]) . 'M')));

    $title  = $xpath->query('.//p[@class="dailyProgram-itemTitle"]/a', $node)->item(0)->nodeValue;
    $movieV = $xpath->query('.//p[@class="dailyProgram-itemTitle"]/a/i[@class="icon_program-movie"]', $node);
    $movie  = false;
    foreach ($movieV as $val) {
      $movie = true;
    }
    $liveV = $xpath->query('.//p[@class="dailyProgram-itemTitle"]/a/i[@class="icon_program-live"]', $node);
    $live  = false;
    foreach ($liveV as $val) {
      $live = true;
    }

    $personalitys = $xpath->query('.//p[@class="dailyProgram-itemPersonality"]/a', $node);
    $personality = [];
    foreach ($personalitys as $p) {
      $personality[] = _trim($p->nodeValue, true);
    }

    $item = [
      'time'        => _trim($time),
      'start'       => _trim($times[0]),
      'startDate'   => $startDate->format('Y-m-d H:i:s'),
      'startU'      => $startDate->format('U'),
      'startDt'     => $startDate,
      'end'         => _trim($times[2]),
      'endDate'     => $endDate->format('Y-m-d H:i:s'),
      'endU'        => $endDate->format('U'),
      'endDt'       => $endDate,
      'title'       => _trim($title, true),
      'personality' => _trim(implode(' ', $personality), true),
      'repeat'      => $repeat,
      'movie'       => $movie,
      'live'        => $live,
    ];

    if (!$ag) {
      unset($item['repeat']);
    }

    $programs[] = $item;
  }

  return $programs;
}

function _trim($text, $slash = false)
{
  $str = mb_convert_encoding($text, 'UTF-8', 'auto');
  $str = trim($str);
  $str = mb_convert_kana($str, 'rnasK');
  $str = preg_replace('/[\n\r\t]/', '', $str);
  $str = preg_replace('/\s{2,}/', '', $str);

  $tHyphen = '/[\x{207B}\x{208B}\x{2010}\x{2012}\x{2013}\x{2014}\x{2015}\x{2212}\x{2500}\x{2501}\x{2796}\x{3161}\x{FF0D}\x{FF70}]/u';
  $rHyphen = '-';
  $str = preg_replace($tHyphen, $rHyphen, $str);

  $patterns     = array('/\?/', '/\*/', '/"/', '/\|/', '/\</', '/\>/', '/\\\/' );
  $replacements = array('？'  , '＊'  , '\'' , '｜'  , '＜'  , '＞'  , '￥'   );
  if ($slash) {
    $patterns     = array_merge($patterns,     array('/\//', '/:/'));
    $replacements = array_merge($replacements, array('／'  , '：' ));
  }
  $str = preg_replace($patterns, $replacements, $str);

  return $str;
}

function programStrcut($title, $personality)
{
  $title       = mb_strcut($title, 0, 200);
  $personality = mb_strcut($personality, 0, 200);
  $program = $title . $personality;
  $program = mb_strcut($program, 0, 200);

  return $program;
}

function sortByKey($keyName, $sortOrder, $array)
{
  foreach ($array as $key => $value) {
    $keyArray[$key] = $value[$keyName];
  }

  array_multisort($keyArray, $sortOrder, $array);

  return $array;
}

function searchDateTime($program, $nowDt)
{
  $search = $nowDt->format('U');
  $ret = [];
  foreach ($program as $p) {
    if ($p['startU'] <= $search && $p['endU'] >= $search) {
      $ret = $p;
    }
  }

  return $ret;
}

function titleConcat($p)
{
  $title = '';
  if (isset($p['title'])) {
    $title .= $p['title'];
    if (isset($p['repeat'])) {
      $title .= $p['repeat'] == true ? '[再]' : '[初]';
    }
    $title .= $p['movie'] == true ? '[動]' : '';
    $title .= $p['live']  == true ? '[生]' : '';
  }

  return $title;
}

function weekDay($day)
{
  $dayTime = strtotime($day);
  $weekDay = array( '日', '月', '火', '水', '木', '金', '土');
  return $weekDay[date('w', $dayTime)];
}

function showProgramTitlePersonality($program)
{
  foreach ($program as $p) {
    if (isset($p['title'])) {
      $title       = titleConcat($p);
      $personality = '';
      if ($p['personality']) {
        $personality = '(' . $p['personality'] . ')';
      }
      $str = programStrcut($title, $personality);
      echo $str, PHP_EOL;
    }
  }
}

function showProgramTitleOnly($program)
{
  foreach ($program as $p) {
    if (isset($p['title'])) {
      $title = titleConcat($p);
      $str = programStrcut($title, '');
      echo $str, PHP_EOL;
    }
  }
}

function showProgramPersonalityOnly($program)
{
  foreach ($program as $p) {
    if (isset($p['personality'])) {
      $str = programStrcut('', $p['personality']);
      echo $str, PHP_EOL;
    }
  }
}

function showProgram($program)
{
  foreach ($program as $p) {
    if (isset($p['title'])) {
      $title       = titleConcat($p);
      $personality = '';
      if ($p['personality']) {
        $personality = '(' . $p['personality'] . ')';
      }
      echo $p['startDt']->format('Y-m-d'), ' ', weekDay($p['startDate']), ' ', $p['startDt']->format('H:i:s'), ' ', $p['endDt']->format('H:i:s'), ' ', $title,  $personality, PHP_EOL;
    }
  }
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

