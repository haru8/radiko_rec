#!/bin/bash
#
# history
#
 
export PATH=/usr/lib/qt-3.3/bin:/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/home/${HOME}/bin
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH

SERVER_NAME1="rtmp://fms-base1.mitene.ad.jp/agqr/aandg2"
SERVER_NAME2="rtmp://fms-base2.mitene.ad.jp/agqr/aandg2"
BASE=/home/haru/radiko_rec
ALLARG="$@"
RUN_DATE=`date '+%Y/%m/%d %H:%M:%S'`
NOW_DATE=`date '+%Y/%m/%d %H:%M:%S'`


usage() {
	local arg
	for arg in $ALLARG; do
		echo -n "'$arg' "
	done
	echo ""
	echo "Usage: `basename $0` time [name]" >&2
	echo "  time      Stop at num seconds into stream" >&2
	echo "  name      output file name" >&2
}

# 録音時間チェック
#  $1 = 録音時間(秒)
time_check() {
	expr  0 + $1 > /dev/null 2>&1
	if [ $? != 0 ]; then
		usage
		exit 2
	fi
}

#
# rtmpdump
#  $1 
#  $2 
rec() {
	local rec_time=$1
	local filename="$2"
	local -i num=$RANDOM%2+1

	if [ $num -eq 1 ]; then
		SERVER_NAME=$SERVER_NAME1
	else
		SERVER_NAME=$SERVER_NAME2
	fi
	echo $SERVER_NAME

	rtmpdump -v \
	    -r "${SERVER_NAME}" \
	    --live \
	    --stop $rec_time \
	    -m 30 \
	    -o "${filename}"
	RET=$?
	return $RET
}

# 28時間制の日時を作成。
create_28date() {
    NOW_DATE=`date '+%Y/%m/%d %H:%M:%S'`
	local -i h=`date -d "$NOW_DATE" '+%k'`
	local -i hh
	local -i hhh
	if [ $h -le 4 ]; then
		hh=$h+24
		hhh=`printf '%02d\n' $hh`
		YMD=`date -d "$NOW_DATE 1 days ago" '+%Y%m%d(%a)'`
		YEAR=`date -d "$NOW_DATE 1 days ago" '+%Y'`
		YMD_HMS=`date -d "$NOW_DATE 1 days ago" "+%Y%m%d_$hhh%M%S"`
		JYMD_HM=`date -d "$NOW_DATE 1 days ago" "+%x $hhh時%M分%S秒"`
	else
		hh="$h"
		hhh=`printf '%02d\n' $hh`
		YMD=`date -d "$NOW_DATE" '+%Y%m%d(%a)'`
		YEAR=`date -d "$NOW_DATE" '+%Y'`
		YMD_HMS=`date -d "$NOW_DATE" "+%Y%m%d_$hhh%M%S"`
		JYMD_HM=`date -d "$NOW_DATE" "+%x $hhh時%M分%S秒"`
	fi

    #echo 'h      : ' $h
    #echo 'hh     : ' $hh
    #echo 'hhh    : ' $hhh
    #echo 'YMD    : ' $YMD
    #echo 'YEAR   : ' $YEAR
    #echo 'YMD_HMS: ' $YMD_HMS
    #echo 'JYMD_HM: ' $JYMD_HM
}

# 録音ファイル名を作成
create_filename() {
	create_28date

	# 保存ディレクトリ
	DIR=$BASE/$YMD

	# 引数チェック
	STOP=$1
    STATION="超!A&G+"
    local -i run_s=`date -d "$RUN_DATE" '+%s'`
    local -i now_s=`date -d "$NOW_DATE" '+%s'`
    local -i delay=$now_s-$run_s
    STOP=$STOP-$delay+5
	time_check $STOP

	if [ $# = 1 ]; then
		# ファイル名指定なし
		NAME=""
		FILE=$DIR/${YMD_HMS}_${STATION}_${STOP}
	elif [ $# = 2 ]; then
		# ファイル名指定有り
		NAME="$2"
		FILE=$DIR/${YMD_HMS}_${NAME}\(${STATION}\)_${STOP}
	else
		usage
		exit 3
	fi

	if [ ! -d "${DIR}" ]; then
		mkdir -p "${DIR}"
	fi

	REC_MIN=$STOP/60
    REC_SEC="$STOP-($REC_MIN*60)"
	FLV="${FILE}.flv"
	MP4="${FILE}.mp4"
	MP3="${FILE}.mp3"
	
	echo 'now date :' $RUN_DATE
	#echo 'run_s    :' $run_s
	#echo 'now_s    :' $now_s
	echo 'delay    :' $delay
	echo 'STOP     :' $STOP
	echo 'YMD      :' $YMD
	echo 'DIR      :' $DIR
	echo 'FLV      :' $FLV
	echo 'MP4      :' $MP4
	echo 'MP3      :' $MP3
	echo ''
}

echo run date : $RUN_DATE

declare -i REC_MIN
declare -i REC_SEC
declare -i STOP
create_filename "$@"

# 録音実施
declare -i REC_CNT=1
declare -i REC_MAX=10
RETVAL1=10
#while [ ! -s "${FLV}" -a $RETVAL1 != 0 ]; do
while [ $RETVAL1 != 0 ]; do
	echo -n rec start : 
	date
	create_filename "$@"
    echo "REC_CNT = $REC_CNT"
	echo ''

	rec $STOP "${FLV}"
	RETVAL1=$?
	echo "rec RETVAL1 = $RETVAL1"
	echo ''
    REC_CNT=$REC_CNT+1
	if [ $REC_CNT -gt $REC_MAX ]; then
		exit 1
	fi
done

#
# ffmpeg flv->mp4
#
echo -n 'ffmpeg flv->mp4 start : '
date
/usr/local/bin/ffmpeg \
  -y -i "${FLV}" \
  -vcodec copy -acodec copy \
  "${MP4}"

RETVAL2=$?
echo "ffmpeg RETVAL2 = $RETVAL2"
echo -n 'ffmpeg flv->mp4 end   : '
date
echo ''

#
# ffmpeg flv->mp3
#
echo -n 'ffmpeg flv->mp3 start : '
date
/usr/local/bin/ffmpeg \
  -y -i "${FLV}" \
  -ab 96 -ar 22050 -acodec libmp3lame \
  "${MP3}"

RETVAL3=$?
echo "ffmpeg RETVAL3 = $RETVAL3"
echo -n 'ffmpeg flv->mp3 end   : '
date
echo ''


if [ $RETVAL1 != 0 ]; then
	exit 2
fi

MAX='101'
MIN='97'
FLV_SIZE=`ls -l "${FLV}" | awk '{ print $5}'`
MP4_SIZE=`ls -l "${MP4}" | awk '{ print $5}'`
RATIO=`perl -e "printf(\"%d\n\", ($MP4_SIZE / $FLV_SIZE * 100) + 0.5);"`
echo RATIO=$RATIO  FLV_SIZE=$FLV_SIZE  MP4_SIZE=$MP4_SIZE
echo MAX=$MAX  MIN=$MIN

if [ $RETVAL1 -eq 0 -a $RETVAL2 -eq 0 ]; then
	if [ $RATIO -le $MAX -a $RATIO -ge $MIN ]; then
		#echo true
		echo "rm ${FLV}"
		rm "${FLV}"
	else
		#echo false
		echo "rm skip."
	fi
fi


#vim: ts=4:sw=4

