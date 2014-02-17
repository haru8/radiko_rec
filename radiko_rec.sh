#!/bin/sh

export PATH=/usr/lib/qt-3.3/bin:/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/home/haru/bin
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH

BASE=/home/haru/radiko_rec

usage(){
	echo "Usage: `basename $0` station time [name]" >&2
	echo "  station   文化放送     : QRR" >&2
	echo "            TBSラジオ    : TBS" >&2
	echo "            ニッポン放送 : LFR" >&2
	echo "            ラジオNIKKEI : NSB" >&2
	echo "            TOKYO FM     : FMT" >&2
	echo "            InterFM      : INT" >&2
	echo "            J-WAVE       : FMJ" >&2
	echo "  time      Stop at num seconds into stream" >&2
	echo "  name      output file name" >&2
}

station_check(){
	case "$ST" in
		QRR)	STATION='文化放送'		;;
		TBS)	STATION='TBSラジオ'		;;
		LFR)	STATION='ニッポン放送'	;;
		NSB)	STATION='ラジオNIKKEI'	;;
		FMT)	STATION='TOKYO FM'		;;
		INT)	STATION='InterFM'		;;
		FMJ)	STATION='J-WAVE'		;;
		*)		usage
				exit 1
				;;
	esac
}

time_check(){
	expr  0 + $STOP>/dev/null 2>&1
	if [ $? != 0 ]; then
		usage
		exit 2
	fi
}

#28時間制の日時を作成。
H=`date '+%H'`
declare -i HH
if [ $H -le 4 ]; then
	HH=$H+24
	HHH=`printf '%02d\n' $HH`
	YMD=`date --date '1 days ago' '+%Y%m%d'`
	YEAR=`date --date '1 days ago' '+%Y'`
	YMD_HMS=`date --date '1 days ago' "+%Y%m%d_$HHH%M%S"`
	JYMD_HM=`date --date '1 days ago' "+%x $HHH時%M分"`
else
	HH=$H
	HHH=`printf '%02d\n' $HH`
	YMD=`date '+%Y%m%d'`
	YEAR=`date '+%Y'`
	YMD_HMS=`date "+%Y%m%d_$HHH%M%S"`
	JYMD_HM=`date "+%x $HHH時%M分"`
fi

DIR=$BASE/$YMD

# 引数チェック
if [ $# = 2 ]; then
	ST=$1
	station_check
	STOP=$2
	time_check
	NAME=""
	FILE=$DIR/${YMD_HMS}_${ST}_${STOP}
elif [ $# = 3 ]; then
	ST=$1
	station_check
	STOP=$2
	time_check
	NAME="$3"
	FILE=$DIR/${YMD_HMS}_${NAME}\(${STATION}\)_${STOP}
else
	usage
	exit 3
fi
declare -i REC_MIN=$STOP/60


mkdir -p "$DIR"

rtmpdump --stop $STOP \
--rtmp "rtmpe://radiko.smartstream.ne.jp" \
--playpath "simul-stream" \
--app "$ST/_defInst_" \
--flashVer "WIN 10,0,45,2" \
--live \
--flv "${FILE}.flv"

ffmpeg -i "${FILE}.flv" \
-vn -acodec libmp3lame -ab 48k \
"${FILE}.mp3"


#eyeD3 \
#--album="$NAME" \
#--title="$NAME" \
#--year="$YEAR"  \
#--comment="jpn:date:${JYMD_HM}～${REC_MIN}分" \
#"${FILE}.mp3"

#mp3gain "$DIR/${YMD_HMS}_${ST}_${STOP}.mp3"
#TMPFILE=`mktemp`
#
#mp3gain -s c "$DIR/${YMD_HMS}_${ST}_${STOP}.mp3" > $TMPFILE
#mp3gain -s d "$DIR/${YMD_HMS}_${ST}_${STOP}.mp3"
#
#TRACK_GAIN=`awk '/^Recommended "Track" dB / { printf("%+.2f dB", $5)   }' $TMPFILE`
#ALBUM_GAIN=`awk '/^Recommended "Album" dB / { printf("%+.2f dB", $5)   }' $TMPFILE`
#TRACK_PEAK=`awk '/^Max PCM /                { printf("%.6f", $7/32768) }' $TMPFILE`
#ALBUM_PEAK=`awk '/^Max Album PCM /          { printf("%.6f", $8/32768) }' $TMPFILE`
#
#eyeD3 \
#--set-user-text-frame="replaygain_track_gain:$TRACK_GAIN" \
#--set-user-text-frame="replaygain_track_peak:$TRACK_PEAK" \
#--set-user-text-frame="replaygain_album_gain:$ALBUM_GAIN" \
#--set-user-text-frame="replaygain_album_peak:$ALBUM_PEAK" \
#"$DIR/${YMD_HMS}_${ST}_${STOP}.mp3"
#
#rm -f $TMPFILE

