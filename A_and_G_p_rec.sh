#!/bin/bash
#
# history
#
 
export PATH=/usr/lib/qt-3.3/bin:/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/home/${HOME}/bin
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH

#SERVER_NAME1="rtmp://fms-base1.mitene.ad.jp/agqr/aandg2"
#SERVER_NAME2="rtmp://fms-base2.mitene.ad.jp/agqr/aandg2"
#SERVER_NAME1="rtmp://fms-base1.mitene.ad.jp/agqr/aandg11"
#SERVER_NAME2="rtmp://fms-base2.mitene.ad.jp/agqr/aandg11"
SERVER_NAME1="rtmp://fms-base1.mitene.ad.jp/agqr/"
SERVER_NAME2="rtmp://fms-base2.mitene.ad.jp/agqr/"
PLAYPATH1="aandg22"
PLAYPATH2="aandg111"
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
	local -i snum=$RANDOM%2+1
	local -i pnum=$RANDOM%2+1

	if [ $snum -eq 1 ]; then
		SERVER_NAME=$SERVER_NAME1
	else
		SERVER_NAME=$SERVER_NAME2
	fi

	if [ $pnum -eq 1 ]; then
		PLAYPATH=$PLAYPATH1
	else
		PLAYPATH=$PLAYPATH2
	fi
	SERVER_NAME="${SERVER_NAME}${PLAYPATH}"
	echo $SERVER_NAME

	rtmpdump -v \
	    -r "${SERVER_NAME}" \
	    --live \
	    --stop $rec_time \
	    -m 10 \
	    -o "${filename}"
	#rtmpdump -v \
	#    --rtmp     "rtmpe://fms2.uniqueradio.jp/" \
    #    --playpath "aandg22" \
    #    --app      "?rtmp://fms-base1.mitene.ad.jp/agqr/" \
	#    --live \
	#    --stop $rec_time \
	#    -m 30 \
	#    -o "${filename}"
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
	FLVS+=("$FLV")
	MP4="${FILE}.mp4"
	MP4S+=("$MP4")
	M4A="${FILE}.m4a"
	M4AS+=("$M4A")
	MP3="${FILE}.mp3"
	MP3S+=("$MP3")
	
	echo 'now date :' $RUN_DATE
	#echo 'run_s    :' $run_s
	#echo 'now_s    :' $now_s
	echo 'delay    :' $delay
	echo 'STOP     :' $STOP
	echo 'YMD      :' $YMD
	echo 'DIR      :' $DIR
	echo 'FLV      :' $FLV
	echo 'MP4      :' $MP4
	echo 'M4A      :' $M4A
	echo 'MP3      :' $MP3
	echo ''
}

echo run date : $RUN_DATE

declare -i REC_MIN
declare -i REC_SEC
declare -i STOP

# 録音実施
declare -i REC_CNT=1
declare -i REC_MAX=30
RETVAL1=10
#while [ ! -s "$FLV" -a $RETVAL1 != 0 ]; do
while [ $RETVAL1 != 0 ]; do
	echo -n rec start : 
	date
	create_filename "$@"
    echo "REC_CNT = $REC_CNT"
	echo ''

	rec $STOP "$FLV"
	RETVAL1=$?
	echo "rec RETVAL1 = $RETVAL1"
	echo ''
    REC_CNT=$REC_CNT+1
	if [ $REC_CNT -gt $REC_MAX ]; then
		break
	fi
done

# 容量0のファイルを削除
find $BASE/ -type f -size 0 -print0 -exec rm {} \;

declare -i LOOP_MAX="${#FLVS[@]}"
declare -i LOOP_CNT=0
MAX='101'
MIN='97'
echo LOOP_MAX=$LOOP_MAX
while [ $LOOP_CNT -lt $LOOP_MAX ]; do
	echo LOOP_CNT=$LOOP_CNT

	FLVFILE="${FLVS[$LOOP_CNT]}"
	MP4FILE="${MP4S[$LOOP_CNT]}"
	M4AFILE="${M4AS[$LOOP_CNT]}"
	MP3FILE="${MP3S[$LOOP_CNT]}"
	echo "$FLVFILE"
	echo "$MP4FILE"
	echo "$M4AFILE"
	echo "$MP3FILE"

	if [ -f "$FLVFILE" ]; then
		# ffmpeg flv->mp4
		echo -n 'ffmpeg flv->mp4 start : '
		date
		/usr/local/bin/ffmpeg \
		  -y -i "$FLVFILE" \
		  -vcodec copy -acodec copy \
		  "$MP4FILE"
		
		RETVAL2=$?
		echo "ffmpeg RETVAL2 = $RETVAL2"
		echo -n 'ffmpeg flv->mp4 end   : '
		date
		echo ''

		# ffmpeg flv->mp3
		#echo -n 'ffmpeg flv->mp3 start : '
		#date
		#/usr/local/bin/ffmpeg \
		#  -y -i "$FLVFILE" \
		#  -ab 96 -ar 22050 -acodec libmp3lame \
		#  "$MP3FILE"
		#
		#RETVAL3=$?
		#echo "ffmpeg RETVAL3 = $RETVAL3"
		#echo -n 'ffmpeg flv->mp3 end   : '
		#date
		#echo ''

		# ffmpeg flv->m4a
		echo -n 'ffmpeg flv->m4a start : '
		date
		/usr/local/bin/ffmpeg \
		  -y -i "$FLVFILE" \
		  -vn -acodec copy \
		  "$M4AFILE"
		
		RETVAL3=$?
		echo "ffmpeg RETVAL3 = $RETVAL3"
		echo -n 'ffmpeg flv->m4a end   : '
		date
		echo ''

		# ffmpeg m4a->mp3
		if [ $RETVAL3 = 0 ]; then
			echo -n 'ffmpeg m4a->mp3 start : '
			date
			/usr/local/bin/ffmpeg \
			  -y -i "$M4AFILE" \
			  -vn -ab 96 -ar 22050  -acodec libmp3lame \
			  "$MP3FILE"
			
			RETVAL4=$?
			echo "ffmpeg RETVAL4 = $RETVAL4"
			echo -n 'ffmpeg m4a->mp3 end   : '
			date
			echo ''
			rm "$M4AFILE"
		fi

		FLV_SIZE=`ls -l "$FLVFILE" | awk '{ print $5}'`
		MP4_SIZE=`ls -l "$MP4FILE" | awk '{ print $5}'`
		RATIO=`perl -e "printf(\"%d\n\", ($MP4_SIZE / $FLV_SIZE * 100) + 0.5);"`
		echo RATIO=$RATIO  FLV_SIZE=$FLV_SIZE  MP4_SIZE=$MP4_SIZE
		echo MAX=$MAX  MIN=$MIN

		if [ $RETVAL1 -eq 0 -a $RETVAL2 -eq 0 ]; then
			if [ $RATIO -le $MAX -a $RATIO -ge $MIN ]; then
				echo "rm $FLVFILE"
				rm "$FLVFILE"
			else
				echo "rm skip."
			fi
		fi
	fi
	LOOP_CNT=$LOOP_CNT+1
done

if [ $RETVAL1 != 0 ]; then
	exit 2
fi

#vim: ts=4:sw=4

