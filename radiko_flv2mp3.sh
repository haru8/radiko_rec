#!/bin/sh

BASE=/home/haru/radiko_rec/
#BASE=/home/haru/radiko_rec/2017/

echo "=============== `date` $TESTTXT start ==============="
export PATH=/usr/local/bin:$PATH
echo $PATH

# 引数のチェック
if [ $# -ge 1 ] ; then
    if [ $1 = '--go' ] ; then
        TESTMODE=0
        TESTTXT=""
    else
        TESTMODE=1
        TESTTXT="TEST MODE"
    fi
else
  TESTMODE=1
  TESTTXT="TEST MODE"
fi


#FLVS=`find $BASE -name '*.flv' -type f -mmin +10`
FLVS=`find $BASE -not -iwholename '*/2018/*' -not -iwholename '*/2017/*' -name '*.flv' -type f -mmin +10`

MAX=110
MIN=90

duration_get() {
    local ifile="$1"
    local duration=0

    duration=`ffprobe -v quiet -hide_banner -show_entries format=duration "$ifile" | grep duration | sed 's/duration=//;s/\..*//'`
    expr ${duration} + 1 > /dev/null 2>&1
    if [ $? -lt 2 ] ; then
        echo $duration
    else
        echo 0
    fi
}

audio_only_check() {
    local ifile="$1"
    local codec_type=""
    local -i codec_num=0
    local codec_audio=""

    codec_type=`ffprobe -v quiet -hide_banner -show_streams -of flat "$ifile" | grep codec_type=`
    codec_num=`echo "$codec_type" | wc -l`
    if [ $codec_num -eq 1 ]; then
        codec_audio=`echo "$codec_type" | grep audio`
        if [ $? -eq 0 ]; then
            echo "OK"
            return 0
        fi
    fi

    echo "NG"
    return 1
}

rate_calc() {
    local -i flv_dura=$1
    local -i mp3_dura=$2
    local rate

    if [ $flv_dura -eq 0 ]; then
        echo 0
        return 1
    fi
    rate=`perl -e "printf(\"%d\n\", ($mp3_dura / $flv_dura * 100) + 0.5);"`
    if [ $? -eq 0 ]; then
        echo $rate
        return 0
    else
        echo 0
        return 1
    fi
}

rate_check() {
    local -i rate=$1

    if [ $rate -le $MAX -a $rate -ge $MIN ]; then
        echo "OK"
        return 0
    else
        echo "NG"
        return 1
    fi
}

flv2mp3_enc() {
    local ifile="$1"
    local ofile="$2"

    echo ffmpeg -y -i "$ifile" -aq 9 -ar 22050 -ac 2 -acodec libmp3lame "$ofile"
    if [ $TESTMODE -eq 0 ]; then
        ffmpeg -y -i "$ifile" -aq 9 -ar 22050 -ac 2 -acodec libmp3lame "$ofile"
    fi
}

declare -i NUM=0
declare -i EXIST_RM_NUM=0
declare -i ENC_NUM=0
declare -i RM_SKIP_NUM=0
declare -i OTHER_AUDIO_NUM=0

PRE_IFS=$IFS
IFS=$'\n'
for FLV in $FLVS; do
    NUM=$NUM+1
    echo
    echo "NUM=$NUM"
    MP3=`echo "$FLV" | sed 's/\.flv$/.mp3/'`
    declare -i FLVDURATION=0
    declare -i MP3DURATION=0
    if [ -f "$FLV" ]; then
        AUDIO_CHECK=`audio_only_check "$FLV"`
        if [ $AUDIO_CHECK != "OK" ]; then
            echo "$FLV"
            ls -lh "$FLV"
            echo "オーディオ以外のストリームが含まれています. skip."
            OTHER_AUDIO_NUM=$OTHER_AUDIO_NUM+1
            continue
        fi
        if [ -f "$MP3" ]; then
            echo "$FLV"
            echo "MP3 exist."
        else
            echo "MP3 not exist."
            echo "ENC: " "$FLV"
            flv2mp3_enc "$FLV" "$MP3"
            ENC_NUM=$ENC_NUM+1
        fi

        if [ -f "$MP3" ]; then
            ls -lh "$FLV"
            ls -lh "$MP3"
            FLVDURATION=`duration_get "$FLV"`
            MP3DURATION=`duration_get "$MP3"`
            RATE=`rate_calc $FLVDURATION $MP3DURATION`
            RATE_CHECK=`rate_check $RATE`
            #echo "FLVDURATION=${FLVDURATION}"
            #echo "MP3DURATION=${MP3DURATION}"
            echo "RATE=${RATE}%"
            #echo $RATE_CHECK
            if [ $RATE_CHECK = "OK" ]; then
                echo "rm ${FLV}"
                if [ $TESTMODE -eq 0 ]; then
                    rm "$FLV"
                fi
                EXIST_RM_NUM=$EXIST_RM_NUM+1
            else
                echo "`printf '%06s sec' ${FLVDURATION}` $FLV"
                echo "`printf '%06s sec' ${MP3DURATION}` $MP3"
                echo "RATE=${RATE}%. rm skip."
                RM_SKIP_NUM=$RM_SKIP_NUM+1
            fi
        fi
    fi
done
IFS=$PRE_IFS

echo
echo "NUM=$NUM"
echo "EXIST_RM_NUM=$EXIST_RM_NUM"
echo "ENC_NUM=$ENC_NUM"
echo "RM_SKIP_NUM=$RM_SKIP_NUM"
echo "OTHER_AUDIO_NUM=$OTHER_AUDIO_NUM"
echo "=============== `date` $TESTTXT end   ==============="
echo

