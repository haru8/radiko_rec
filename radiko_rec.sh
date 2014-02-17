#!/bin/bash
#
# history
#
# Rev	Date		Name	notes
# 1	2011-3-29	7K3VEY	sanko:	http://yuzuru.2ch.net/test/read.cgi/pc2nanmin/1271066265/343
#					http://gist.github.com/875864
# 0	2010-5-2	7K3VEY	first issue.
 
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
	echo "            bayfm78      : BAYFM78" >&2
	echo "            NACK5        : NACK5" >&2
	echo "            FMヨコハマ   : YFM" >&2
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
		BAYFM78)STATION='bayfm78'		;;
		NACK5)	STATION='NACK5'			;;
		YFM)	STATION='FMヨコハマ'	;;
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
H=`date '+%k'`
declare -i HH
if [ $H -le 4 ]; then
	HH=$H+24
	HHH=`printf '%02d\n' $HH`
	YMD=`date --date '1 days ago' '+%Y%m%d(%a)'`
	YEAR=`date --date '1 days ago' '+%Y'`
	YMD_HMS=`date --date '1 days ago' "+%Y%m%d_$HHH%M%S"`
	JYMD_HM=`date --date '1 days ago' "+%x $HHH時%M分"`
else
	HH="$H"
	HHH=`printf '%02d\n' $HH`
	YMD=`date '+%Y%m%d(%a)'`
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
FLV="${FILE}.flv"
MP3="${FILE}.mp3"

mkdir -p "${DIR}"

rec_time=10  # sec
file_prefix=$1
##file_prefix=joqr
file_suffix=`date +%Y-%m-%d-%H%M`
#file_name=$file_prefix-$file_suffix

server_name=radiko.smartstream.ne.jp
#server_name=7k3vey-macromedia-fcs.ham-radio-op.net # for cyukei but old
#server_name=localhost  # for test
server_port=1935

echo YMD : $YMD
echo DIR : $DIR
echo FLV : $FLV
echo MP3 : $MP3
#exit

playerurl=http://radiko.jp/player/swf/player_2.0.1.00.swf
playerfile="${HOME}/bin/player.swf"
keyfile="${HOME}/bin/authkey.png"
authfile="${HOME}/bin/auth1_fms.$$"
authfile2="${HOME}/bin/auth2_fms.$$"

channel=$1
if [ $# -eq 1 ]; then
  output="${FLV}"
elif [ $# -eq 2 ]; then
  rec_time=$2
  output="${FLV}"
elif [ $# -eq 3 ]; then
  rec_time=$2
  output=$3
else
  echo "usage : $0 channel_name [rectime(sec)] [outputfile]"
  exit 1
fi

#
# get player
#
if [ ! -f $playerfile ]; then
wget -q -O $playerfile $playerurl

  if [ $? -ne 0 ]; then
echo "failed get player"
    exit 1
  fi
fi

#
# get keydata (need swftools)
#
if [ ! -f $keyfile ]; then
swfextract -b 5 $playerfile -o $keyfile

  if [ ! -f $keyfile ]; then
echo "failed get keydata"
    exit 1
  fi
fi

if [ -f $authfile ]; then
rm -f $authfile
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
     -O $authfile \
     https://radiko.jp/v2/api/auth1_fms

if [ $? -ne 0 ]; then
echo "failed auth1 process"
  exit 1
fi

#
# get partial key
#
authtoken=`cat $authfile | perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)'`
offset=`cat $authfile | perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)'`
length=`cat $authfile | perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)'`

partialkey=`dd if=$keyfile bs=1 skip=${offset} count=${length} 2> /dev/null | base64`

echo "authtoken: ${authtoken} \noffset: ${offset} length: ${length} \npartialkey: $partialkey"

rm -f $authfile

if [ -f $authfile2 ]; then
rm -f $authfile2
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
     --header="X-Radiko-Authtoken: ${authtoken}" \
     --header="X-Radiko-Partialkey: ${partialkey}" \
     --post-data='\r\n' \
     --no-check-certificate \
     -O $authfile2 \
     https://radiko.jp/v2/api/auth2_fms

if [ $? -ne 0 -o ! -f $authfile2 ]; then
echo "failed auth2 process"
  exit 1
fi

echo "authentication success"

areaid=`cat $authfile2 | perl -ne 'print $1 if(/^([^,]+),/i)'`
echo "areaid: $areaid"

rm -f $authfile2

#
# rtmpdump
#
rtmpdump -v \
	 --stop $rec_time \
         -r "rtmpe://$server_name:$server_port" \
         --playpath "simul-stream" \
         --app "${channel}/_defInst_" \
         -W $playerurl \
         -C S:"" -C S:"" -C S:"" -C S:$authtoken \
         --live \
         --flv "${FLV}"

RETVAL1=$?
#if [ $RETVAL != 0 ]; then
#	exit 1
#fi

#
# ffmpeg flv->mp3
#
date
/usr/local/bin/ffmpeg -y -i "${FLV}" -acodec libmp3lame -aq 9 "${MP3}"
RETVAL2=$?
date

#if [ $RETVAL != 0 ]; then
#	exit 2
#fi

MAX='130'
MIN='120'
FLV_SIZE=`ls -l "${FLV}" | awk '{ print $5}'`
MP3_SIZE=`ls -l "${MP3}" | awk '{ print $5}'`
RATIO=`perl -e "printf(\"%d\n\", ($MP3_SIZE / $FLV_SIZE * 100) + 0.5);"`
echo RATIO=$RATIO
echo MAX=$MAX
echo MIN=$MIN

if [ $RETVAL1 -eq 0 -a $RETVAL2 -eq 0 ]; then
	#if [ $RATIO -le $MAX -a $RATIO -ge $MIN ]; then
	#	#echo true
	#	echo "rm ${FLV}"
		rm "${FLV}"
	#else
	#	#echo false
	#	echo
	#fi
fi

