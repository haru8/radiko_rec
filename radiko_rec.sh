#!/bin/bash
#
# history
#

# 配信サーバーはxmlから取るようにしたい。
# http://radiko.jp/v2/station/stream/QRR.xml
# http://radiko.jp/v2/station/stream_multi/QRR.xml
 
export PATH=/usr/lib/qt-3.3/bin:/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/home/${HOME}/bin
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH

BASE=/home/haru/radiko_rec
SERVER_NAME='rtmpe://f-radiko.smartstream.ne.jp'
SERVER_PORT=1935
PLAYERURL=http://radiko.jp/player/swf/player_3.0.0.01.swf
PLAYPATH='simul-stream.stream'
PLAYERFILE="${HOME}/bin/player.swf"
KEYFILE="${HOME}/bin/authkey.png"
AUTHFILE1="${HOME}/bin/auth1_fms.$$"
AUTHFILE2="${HOME}/bin/auth2_fms.$$"
AUTHFILE1URL=https://radiko.jp/v2/api/auth1_fms
AUTHFILE2URL=https://radiko.jp/v2/api/auth2_fms

SERVER_NHKR1='rtmpe://netradio-r1-flash.nhk.jp'
SERVER_NHKR2='rtmpe://netradio-r2-flash.nhk.jp'
SERVER_NHKFM='rtmpe://netradio-fm-flash.nhk.jp'
PLAYPATH_NHKR1='NetRadio_R1_flash@63346'
PLAYPATH_NHKR2='NetRadio_R2_flash@63342'
PLAYPATH_NHKFM='NetRadio_FM_flash@63343'
PLAYERURL_NHK=http://www3.nhk.or.jp/netradio/files/swf/rtmpe.swf
ALLARG="$@"
ARGC=$#
RUN_DATE=`date '+%Y/%m/%d %H:%M:%S'`
NOW_DATE=`date '+%Y/%m/%d %H:%M:%S'`


usage() {
	local arg
	echo count = $ARGC
	for arg in $ALLARG; do
		echo -n "'$arg' "
	done
	echo ""
	echo "Usage: `basename $0` station time [name]" >&2
	echo "  station   文化放送     : QRR" >&2
	echo "            TBSラジオ    : TBS" >&2
	echo "            ニッポン放送 : LFR" >&2
	echo "            ラジオNIKKEI : NSB" >&2
	echo "            TOKYO FM     : FMT" >&2
	echo "            InterFM      : INT" >&2
	echo "            J-WAVE       : FMJ" >&2
	echo "            bayfm78      : BAYFM78" >&2
	echo "            NACK5        : NACK5" >&2
	echo "            ラジオ日本   : JORF" >&2
	echo "            FMヨコハマ   : YFM" >&2
	echo "            東海ラジオ   : TOKAIRADIO" >&2
	echo "            レディオキューブFM三重 : FMMIE" >&2
	echo "            CBCラジオ    : CBC" >&2
	echo "            NHK第一放送  : NHKR1" >&2
	echo "            NHK第二放送  : NHKR2" >&2
	echo "            NHK FM       : NHKFM" >&2
	echo "  time      Stop at num seconds into stream" >&2
	echo "  name      output file name" >&2
}

# 放送局チェック
# http://www.dcc-jpl.com/foltia/wiki/radikomemo
#  $1 = 放送局
station_check() {
	ISNHK=0
	case "$1" in
		QRR)	STATION='文化放送'		;;
		TBS)	STATION='TBSラジオ'		;;
		LFR)	STATION='ニッポン放送'	;;
		NSB)	STATION='ラジオNIKKEI'	;;
		FMT)	STATION='TOKYO FM'		;;
		INT)	STATION='InterFM'		;;
		FMJ)	STATION='J-WAVE'		;;
		BAYFM78)STATION='bayfm78'		;;
		NACK5)	STATION='NACK5'			;;
		JORF)	STATION='ラジオ日本'    ;;
		YFM)	STATION='FMヨコハマ'	;;
		TOKAIRADIO) STATION='東海ラジオ' ;;
		FMMIE)	STATION='レディオキューブFM三重' ;;
		CBC)	STATION='CBCラジオ' ;;
		NHKR1)	STATION='NHK第一放送'
				ISNHK=1
				SERVER_NAME=$SERVER_NHKR1
				PLAYPATH=$PLAYPATH_NHKR1
				PLAYERURL=$PLAYERURL_NHK
				;;
		NHKR2)	STATION='NHK第二放送'
				ISNHK=1
				SERVER_NAME=$SERVER_NHKR2
				PLAYPATH=$PLAYPATH_NHKR2
				PLAYERURL=$PLAYERURL_NHK
				;;
		NHKFM)	STATION='NHK FM'
				ISNHK=1
				SERVER_NAME=$SERVER_NHKFM
				PLAYPATH=$PLAYPATH_NHKFM
				PLAYERURL=$PLAYERURL_NHK
				;;
		*)		usage
				exit 1
				;;
	esac
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

# 認証キー取得
get_auth() {
	#
	# get player
	#
	if [ ! -s $PLAYERFILE ]; then
		wget -q -O $PLAYERFILE $PLAYERURL
	
		if [ $? -ne 0 ]; then
			echo "failed get player"
			exit 1
		fi
	fi
	
	#
	# get keydata (need swftools)
	#
	if [ ! -s $KEYFILE ]; then
		swfextract -b 14 $PLAYERFILE -o $KEYFILE
	
	  if [ ! -s $KEYFILE ]; then
		echo "failed get keydata"
		exit 1
		fi
	fi
	
	if [ -f $AUTHFILE1 ]; then
		rm -f $AUTHFILE1
	fi
	
	#
	# access auth1_fms
	#
	wget -q \
	    --header="pragma: no-cache" \
	    --header="X-Radiko-App: pc_1" \
	    --header="X-Radiko-App-Version: 2.0.1" \
	    --header="X-Radiko-User: test-stream" \
	    --header="X-Radiko-Device: pc" \
	    --post-data='\r\n' \
	    --no-check-certificate \
	    --save-headers \
	    -O $AUTHFILE1 \
	    $AUTHFILE1URL
	
	if [ $? -ne 0 ]; then
		echo "failed auth1 process"
		exit 1
	fi
	
	#
	# get partial key
	#
	AUTHTOKEN=`cat $AUTHFILE1 | perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)'`
	local offset=`cat $AUTHFILE1 | perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)'`
	local length=`cat $AUTHFILE1 | perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)'`
	
	local partialkey=`dd if=$KEYFILE bs=1 skip=${offset} count=${length} 2> /dev/null | base64`
	
	echo "authtoken: ${AUTHTOKEN} \noffset: ${offset} length: ${length} \npartialkey: $partialkey"
	
	rm -f $AUTHFILE1
	
	if [ -f $AUTHFILE2 ]; then
		rm -f $AUTHFILE2
	fi
	
	#
	# access auth2_fms
	#
	wget -q \
	     --header="pragma: no-cache" \
	     --header="X-Radiko-App: pc_1" \
	     --header="X-Radiko-App-Version: 2.0.1" \
	     --header="X-Radiko-User: test-stream" \
	     --header="X-Radiko-Device: pc" \
	     --header="X-Radiko-Authtoken: ${AUTHTOKEN}" \
	     --header="X-Radiko-Partialkey: ${partialkey}" \
	     --post-data='\r\n' \
	     --no-check-certificate \
	     -O $AUTHFILE2 \
	     $AUTHFILE2URL
	
	if [ $? -ne 0 -o ! -f $AUTHFILE2 ]; then
		echo "failed auth2 process"
		exit 1
	fi
	
	echo "authentication success"
	
	areaid=`cat $AUTHFILE2 | perl -ne 'print $1 if(/^([^,]+),/i)'`
	echo "areaid: $areaid"
	echo ''
	
	rm -f $AUTHFILE2
}


#
# rtmpdump
#  $1 
#  $2 
#  $3 
rec() {
	local station=$1
	local rec_time=$2
	local filename="$3"

	if [ $ISNHK = 0 ]; then
		rtmpdump -v \
		    -r "$SERVER_NAME" \
		    --playpath $PLAYPATH \
		    --app "${station}/_definst_" \
		    -W $PLAYERURL \
		    -C S:"" -C S:"" -C S:"" -C S:$AUTHTOKEN \
		    --live \
		    --stop $rec_time \
		    -m 30 \
		    -o "${filename}"
		RET=$?
	else
		rtmpdump -v \
		    -r "$SERVER_NAME" \
		    --playpath $PLAYPATH \
		    --app "live" \
		    -W $PLAYERURL \
		    --live \
		    --stop $rec_time \
		    -m 30 \
		    -o "${filename}"
		RET=$?
	fi
	return $RET
}

# 28時間制の日時を作成。
create_28date() {
	NOW_DATE=`date '+%Y/%m/%d %H:%M:%S'`
	local -i h=`date -d "$NOW_DATE" '+%k'`
	local -i hh
	local hhh
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
	ST=$1
	station_check "$ST"
	STOP=$2
	local -i run_s=`date -d "$RUN_DATE" '+%s'`
	local -i now_s=`date -d "$NOW_DATE" '+%s'`
	local -i delay=$now_s-$run_s
	STOP=$STOP-$delay+5
	STOP=`echo $STOP | sed 's/-//g'`
	time_check $STOP

	if [ $# = 2 ]; then
		# ファイル名指定なし
		NAME=""
		FILE=$DIR/${YMD_HMS}_${ST}_${STOP}
	elif [ $# = 3 ]; then
		# ファイル名指定有り
		NAME="$3"
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
	MP3="${FILE}.mp3"
	
	echo 'now date :' $RUN_DATE
	#echo 'run_s    :' $run_s
	#echo 'now_s    :' $now_s
	echo 'delay    :' $delay
	echo 'STOP     :' $STOP
	echo 'YMD      :' $YMD
	echo 'DIR      :' $DIR
	echo 'FLV      :' $FLV
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
declare -i REC_MAX=20
RETVAL1=10
#while [ ! -s "${FLV}" -a $RETVAL1 != 0 ]; do
while [ $RETVAL1 != 0 ]; do
	echo -n rec start : 
	date
	create_filename "$@"
    echo "REC_CNT = $REC_CNT"
	echo ''
	if [ $ISNHK = 0 ]; then
		get_auth
	fi
	rec $ST $STOP "${FLV}"
	RETVAL1=$?
	echo "rec RETVAL1 = $RETVAL1"
	echo ''
	REC_CNT=$REC_CNT+1
	if [ $REC_CNT -gt $REC_MAX ]; then
		exit 1
	fi
done

#
# ffmpeg flv->mp3
#
echo -n ffmpeg start : 
date
/usr/local/bin/ffmpeg \
  -y -i "${FLV}" \
  -metadata StreamTitle="${NAME} ${JYMD_HM} ～ ${REC_MIN}分${REC_SEC}秒" \
  -metadata author="${STATION}" \
  -metadata artist="${STATION}" \
  -metadata title="${NAME} ${JYMD_HM} ～ ${REC_MIN}分${REC_SEC}秒" \
  -metadata album="${NAME}" \
  -metadata genre="ラジオ" \
  -metadata year="${YEAR}" \
  -metadata comment="${NAME}(${STATION}) ${JYMD_HM} ～ ${REC_MIN}分${REC_SEC}秒" \
  -aq 9 -ar 22050 -ac 2 -acodec libmp3lame "${MP3}"

#  -aq 9 -acodec libmp3lame "${MP3}"
#  -ab 64k -acodec libmp3lame "${MP3}"

RETVAL2=$?
echo "ffmpeg RETVAL2 = $RETVAL2"
echo -n ffmpeg end   : 
date
echo ''

if [ $RETVAL1 != 0 ]; then
	exit 2
fi

MAX='120'
MIN='70'
FLV_SIZE=`ls -l "${FLV}" | awk '{ print $5}'`
MP3_SIZE=`ls -l "${MP3}" | awk '{ print $5}'`
RATIO=`perl -e "printf(\"%d\n\", ($MP3_SIZE / $FLV_SIZE * 100) + 0.5);"`
echo RATIO=$RATIO  FLV_SIZE=$FLV_SIZE  MP3_SIZE=$MP3_SIZE
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

