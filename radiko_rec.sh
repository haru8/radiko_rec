#!/bin/bash
#
# history
#

export PATH=/usr/lib/qt-3.3/bin:/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/home/${HOME}/bin
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH

BASE=/home/haru/radiko_rec
AUTHFILE1="/tmp/auth1_fms.$$"
AUTHFILE2="/tmp/auth2_fms.$$"
AUTHFILE1URL=https://radiko.jp/v2/api/auth1
AUTHFILE2URL=https://radiko.jp/v2/api/auth2
STREAM_URl_BASE=http://radiko.jp/v2/station/stream_smh_multi

# Define authorize key value ( from http://radiko.jp/apps/js/playerCommon.js )
RADIKO_AUTHKEY_VALUE="bcd151073c03b352e1ef2fd66c32209da9ca0afa"


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
    echo "  station   文化放送        : QRR" >&2
    echo "            TBSラジオ       : TBS" >&2
    echo "            ニッポン放送    : LFR" >&2
    echo "            ラジオNIKKEI第1 : RN1" >&2
    echo "            ラジオNIKKEI第2 : RN2" >&2
    echo "            TOKYO FM        : FMT" >&2
    echo "            InterFM         : INT" >&2
    echo "            J-WAVE          : FMJ" >&2
    echo "            bayfm78         : BAYFM78" >&2
    echo "            NACK5           : NACK5" >&2
    echo "            ラジオ日本      : JORF" >&2
    echo "            FMヨコハマ      : YFM" >&2
    echo "            NHK第一放送     : JOAK" >&2
    echo "            NHK第二放送     : JOAB" >&2
    echo "            NHK FM          : JOAK-FM" >&2
    echo ""
    echo "  time      Stop at num seconds into stream" >&2
    echo "  name      output file name" >&2
}

# 放送局チェック
# http://www.dcc-jpl.com/foltia/wiki/radikomemo
#  $1 = 放送局
station_check() {

    case "$1" in
        QRR)    STATION='文化放送'      ;;
        TBS)    STATION='TBSラジオ'     ;;
        LFR)    STATION='ニッポン放送'  ;;
        RN1)    STATION='ラジオNIKKEI第1'   ;;
        RN2)    STATION='ラジオNIKKEI第2'   ;;
        FMT)    STATION='TOKYO FM'      ;;
        INT)    STATION='InterFM'       ;;
        FMJ)    STATION='J-WAVE'        ;;
        BAYFM78)STATION='bayfm78'       ;;
        NACK5)  STATION='NACK5'         ;;
        JORF)   STATION='ラジオ日本'    ;;
        YFM)    STATION='FMヨコハマ'    ;;
        JOAK)   STATION='NHKラジオ第1'  ;;
        JOAB)   STATION='NHKラジオ第2'  ;;
        JOAK-FM) STATION='NHK-FM' ;;
        TOKAIRADIO) STATION='東海ラジオ';;
        FMMIE)  STATION='レディオキューブFM三重' ;;
        CBC)    STATION='CBCラジオ'     ;;

        *)      usage
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
    if [ $1 -lt 0 ]; then
        echo "録音時間がマイナスになりました: $1"
        exit 3
    fi
}

# 認証キー取得
get_auth() {

    if [ -f $AUTHFILE1 ]; then
        rm -f $AUTHFILE1
    fi

    #
    # access auth1
    #
    wget -q \
        --header="pragma: no-cache" \
        --header="X-Radiko-App: pc_html5" \
        --header="X-Radiko-App-Version: 0.0.1" \
        --header="X-Radiko-User: test-stream" \
        --header="X-Radiko-Device: pc" \
        --no-check-certificate \
        --save-headers \
        -O $AUTHFILE1 \
        $AUTHFILE1URL

    if [ $? -ne 0 ]; then
        echo "failed auth1 process"
        return 1
    fi

    #
    # get partial key
    #
    AUTHTOKEN=`cat ${AUTHFILE1} | perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)'`
    local offset=`cat ${AUTHFILE1} | perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)'`
    local length=`cat ${AUTHFILE1} | perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)'`
    local partialkey=`echo "${RADIKO_AUTHKEY_VALUE}" | dd bs=1 "skip=${offset}" "count=${length}" 2> /dev/null | base64`

    echo -e "authtoken: ${AUTHTOKEN} \noffset: ${offset} length: ${length} \npartialkey: ${partialkey}"

    rm -f ${AUTHFILE1}

    if [ -f ${AUTHFILE2} ]; then
        rm -f ${AUTHFILE2}
    fi

    #
    # access auth2
    #
    wget -q \
         --header="pragma: no-cache" \
         --header="X-Radiko-User: test-stream" \
         --header="X-Radiko-Device: pc" \
         --header="X-Radiko-Authtoken: ${AUTHTOKEN}" \
         --header="X-Radiko-Partialkey: ${partialkey}" \
         --no-check-certificate \
         -O ${AUTHFILE2} \
         ${AUTHFILE2URL}

    if [ $? -ne 0 -o ! -f ${AUTHFILE2} ]; then
        echo "failed auth2 process"
        return 1
    fi

    echo "authentication success"

    areaid=`cat ${AUTHFILE2} | perl -ne 'print $1 if(/^([^,]+),/i)'`
    echo "areaid: $areaid"

    rm -f ${AUTHFILE2}
    return 0
}


#
# rec
#  $1
#  $2
#  $3
rec() {
    local station=$1
    local rec_time=$2
    local filename="$3"

    get_auth
    if [ $? = 0 ]; then

        STATION_XML=/tmp/${station}.xml
        if [ -f ${STATION_XML} ]; then
            rm -f ${STATION_XML}
        fi
        echo  STATION_XML: ${STREAM_URl_BASE}/${station}.xml
        wget -q ${STREAM_URl_BASE}/${station}.xml -O ${STATION_XML}
        STREAM_URL=`xmllint --xpath "/urls/url[@areafree='1'][2]/playlist_create_url/text()" ${STATION_XML}`
        rm -f ${STATION_XML}
        echo "stream_url: ${STREAM_URL}"

        echo "放送局: $STATION($ST)
ファイル名: ${filename}
番組名  : ${PGNAME}
引数    : ${CMDTITLE}
開始時間: `date '+%Y/%m/%d %H:%M:%S'`
録音時間: $rec_time" | ~/bin/slack_radiko.sh -h "録音開始: $$"

        ffmpeg \
            -loglevel warning \
            -fflags +discardcorrupt \
            -headers "X-Radiko-Authtoken: ${AUTHTOKEN}" \
            -i "${STREAM_URL}" \
            -acodec copy \
            -vn \
            -bsf:a aac_adtstoasc \
            -y \
            -t ${rec_time} \
            "${filename}"
        RET=$?

        echo "放送局: $STATION($ST)
ファイル名: ${filename}
番組名  : ${PGNAME}
引数    : ${CMDTITLE}
終了時間: `date '+%Y/%m/%d %H:%M:%S'`
録音時間: $rec_time" | ~/bin/slack_radiko.sh -h "録音完了: $$"
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
    DIR=${BASE}/${YMD}

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

    PGTITLE=`~/bin/radiko_prog.php -s $ST -nt`
    PGPRLTY=`~/bin/radiko_prog.php -s $ST -np`
    PGNAME="";
    if [ -n "${PGTITLE}" ]; then
        PGNAME="${PGTITLE}"
    fi
    if [ -n "${PGPRLTY}" ]; then
        PGNAME="${PGTITLE}(${PGPRLTY})"
    fi

    YMD_HMS_CNT=`echo -n "${YMD_HMS}"_ | wc -c`
    STATION_CNT=`echo -n "(${STATION})" | wc -c`
    STOP_CNT=`echo -n "_${STOP}" | wc -c`
    STR_CNT=`expr + ${YMD_HMS_CNT} + ${STATION_CNT} + ${STOP_CNT}`
    FILENAME_STR_MAX=`expr 250 - ${STR_CNT}`
    PGNAME=`php -r "echo mb_strcut(\"${PGNAME}\", 0, ${FILENAME_STR_MAX});"`

    if [ $# = 2 ]; then
        # ファイル名指定なし
        if [ -n "${PGNAME}" ]; then
            NAME="${PGNAME}"
            CMDTITLE=""
            FILEBODY=${YMD_HMS}_${NAME}\(${STATION}\)_${STOP}
            FILEBODY=`php -r "echo mb_strcut(\"${FILEBODY}\", 0, 250);"`
            FILE=${DIR}/${FILEBODY}
        else
            NAME=""
            CMDTITLE=""
            FILE=${DIR}/${YMD_HMS}_${ST}_${STOP}
        fi
    elif [ $# = 3 ]; then
        # ファイル名指定有り
        if [ -n "${PGNAME}" ]; then
            NAME="${PGNAME}"
            CMDTITLE="$3"
            FILEBODY=${YMD_HMS}_${NAME}\(${STATION}\)_${STOP}
            FILEBODY=`php -r "echo mb_strcut(\"${FILEBODY}\", 0, 250);"`
            FILE=${DIR}/${FILEBODY}
        else
            NAME="$3"
            CMDTITLE="$3"
            FILEBODY=${YMD_HMS}_${NAME}\(${STATION}\)_${STOP}
            FILEBODY=`php -r "echo mb_strcut(\"${FILEBODY}\", 0, 250);"`
            FILE=${DIR}/${FILEBODY}
        fi
    else
        usage
        exit 3
    fi

    if [ ! -d "${DIR}" ]; then
        mkdir -p "${DIR}"
    fi

    REC_MIN=$STOP/60
    REC_SEC="$STOP-($REC_MIN*60)"
    M4A="${FILE}.m4a"
    M4AS+=("${M4A}")
    MP3="${FILE}.mp3"
    MP3S+=("${MP3}")

    echo 'now date :' $RUN_DATE
    #echo 'run_s    :' $run_s
    #echo 'now_s    :' $now_s
    echo 'delay    :' $delay
    echo 'STOP     :' $STOP
    echo 'YMD      :' $YMD
    echo 'DIR      :' $DIR
    echo 'M4A      :' $M4A
    echo 'MP3      :' $MP3
    echo ''
}

echo run date : $RUN_DATE

declare -i REC_MIN
declare -i REC_SEC
declare -i STOP
#create_filename "$@"

# 録音実施
declare -i REC_CNT=1
declare -i REC_MAX=30
RETVAL1=10
while [ $RETVAL1 != 0 ]; do
    echo -n rec start :
    date
    create_filename "$@"
    echo "REC_CNT = $REC_CNT"
    echo ''
    rec $ST $STOP "${M4A}"
    RETVAL1=$?
    echo "rec RETVAL1 = $RETVAL1"
    echo ''
    REC_CNT=$REC_CNT+1
    if [ $REC_CNT -gt $REC_MAX ]; then
        break
    fi
done

# 容量0のファイルを削除
find $DIR -type f -size 0 -print0 -exec rm {} \;

#
# ffmpeg flv->mp3
#
declare -i LOOP_MAX="${#M4AS[@]}"
declare -i LOOP_CNT=0
MAX='120'
MIN='70'
echo LOOP_MAX=$LOOP_MAX
while [ $LOOP_CNT -lt $LOOP_MAX ]; do
    echo LOOP_CNT=$LOOP_CNT
    echo -n ffmpeg start :
    date

    M4AFILE="${M4AS[$LOOP_CNT]}"
    MP3FILE="${MP3S[$LOOP_CNT]}"
    echo "$M4AFILE"
    echo "$MP3FILE"
    M4AFILESIZE=''
    MP3FILESIZE=''
    ENC_START=''
    ENC_END=''

    if [ -f "$M4AFILE" ]; then
        ENC_START=`date +%s`
        M4AFILESIZE=`ls -lh "$M4AFILE" | awk '{print $5}'`
        /usr/local/bin/ffmpeg \
          -y -i "$M4AFILE"  \
          -loglevel warning \
          -metadata StreamTitle="${NAME} ${JYMD_HM} ～ ${REC_MIN}分${REC_SEC}秒" \
          -metadata author="${STATION}" \
          -metadata artist="${PGPRLTY}" \
          -metadata title="${PGNAME}" \
          -metadata album="${PGTITLE}" \
          -metadata genre="ラジオ" \
          -metadata year="${YEAR}" \
          -metadata date="${YEAR}" \
          -metadata comment="${STATION}
${JYMD_HM} ～ ${REC_MIN}分${REC_SEC}秒
番組タイトル  : ${PGTITLE}
パーソナリティ: ${PGPRLTY}
${CMDTITLE}" \
          -vn -acodec libmp3lame -ar 22050 -ac 2 -q:a 9 "$MP3FILE"
        RETVAL2=$?
        echo "ffmpeg RETVAL2 = $RETVAL2"
        echo -n ffmpeg end   :
        MP3FILESIZE=`ls -lh "$MP3FILE" | awk '{print $5}'`
        date
        ENC_END=`date +%s`
        echo ''

        M4A_SIZE=`ls -l "$M4AFILE" | awk '{ print $5}'`
        MP3_SIZE=`ls -l "$MP3FILE" | awk '{ print $5}'`
        RATE=`perl -e "printf(\"%d\n\", ($MP3_SIZE / $M4A_SIZE * 100) + 0.5);"`
        echo RATE=$RATE  M4A_SIZE=$M4A_SIZE  MP3_SIZE=$MP3_SIZE
        echo MAX=$MAX  MIN=$MIN

        if [ $RETVAL1 -eq 0 -a $RETVAL2 -eq 0 ]; then
            if [ $RATE -le $MAX -a $RATE -ge $MIN ]; then
                #echo true
                echo "rm $M4AFILE"
                rm "$M4AFILE"
            else
                #echo false
                echo "rm skip."
            fi
        fi
        echo "エンコード結果
LOOP_CNT / LOOP_MAX: ${LOOP_CNT} / ${LOOP_MAX}
終了時間  : `date '+%Y/%m/%d %H:%M:%S'`
エンコード時間 : `expr $ENC_END - $ENC_START`
ファイル名: ${M4AFILE}
番組名    : ${PGNAME}
引数      : ${CMDTITLE}
M4AFILE   : `basename "${M4AFILE}"` : ${M4AFILESIZE}
MP3FILE   : `basename "${MP3FILE}"` : ${MP3FILESIZE}
RATE      : ${RATE} : MAX=$MAX  MIN=$MIN" | ~/bin/slack_radiko.sh -h "エンコード結果: $$"
    fi
    LOOP_CNT=$LOOP_CNT+1
done

if [ $RETVAL1 != 0 ]; then
    exit 2
fi

#vim: ts=4:sw=4

