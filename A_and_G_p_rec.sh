#!/bin/bash
#
# history
#

export PATH=/usr/lib/qt-3.3/bin:/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/home/${HOME}/bin
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH

REC_URL_HOST="https://fms2.uniqueradio.jp/"
REC_URL_PATH="agqr10/aandg1.m3u8"
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
    if [ $1 -lt 0 ]; then
        echo "録音時間がマイナスになりました: $1"
        exit 3
    fi
}

#
# rec
#  $1
#  $2
rec() {
    local rec_time=$1
    local filename="$2"
    local -i pnum=`seq 1 3 | shuf | head -1`

    SERVER_NAME=${REC_URL_HOST}${REC_URL_PATH}

    echo *=======================*
    echo pnum = $pnum
    echo SERVER_NAME = $SERVER_NAME
    echo *=======================*

echo "ファイル名: ${filename}
放送局  : 超A&G+
番組名  : ${PGNAME}
引数    : ${CMDTITLE}
開始時間: `date '+%Y/%m/%d %H:%M:%S'`
録音時間: $rec_time" | ~/bin/slack_agqr.sh -h "録音開始: $$"

    /usr/local/bin/ffmpeg -i \
      "${SERVER_NAME}"       \
      -t $rec_time           \
      -movflags faststart    \
      -acodec copy           \
      -vcodec copy           \
      -bsf:a aac_adtstoasc   \
      -metadata artist=${PGPRLTY}  \
      -metadata title="${PGNAME}"  \
      -metadata album="${PGTITLE}" \
      -metadata genre="ラジオ"     \
      -metadata date="${YEAR}"     \
      -metadata comment="超A&G+
${JYMD_HM} ～ ${REC_MIN}分${REC_SEC}秒
番組タイトル  : ${PGTITLE}
パーソナリティ: ${PGPRLTY}
${NAME}
${CMDTITLE}" \
      "${filename}"

    RET=$?
echo "ファイル名: ${filename}
放送局  : 超A&G+
番組名  : ${PGNAME}
引数    : ${CMDTITLE}
終了時間: `date '+%Y/%m/%d %H:%M:%S'`
録音時間: $rec_time" | ~/bin/slack_agqr.sh -h "録音完了: $$"
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

    PGTITLE=`~/bin/A_and_G_p_prog.php -nt`
    PGPRLTY=`~/bin/A_and_G_p_prog.php -np`
    PGNAME="";
    if [ -n "${PGTITLE}" ]; then
        PGNAME="${PGTITLE}"
    fi
    if [ -n "${PGPRLTY}" ]; then
        PGNAME="${PGTITLE}(${PGPRLTY})"
    fi

    if [ $# = 1 ]; then
        # ファイル名指定なし
        if [ -n "${PGNAME}" ]; then
            NAME="${PGNAME}"
            CMDTITLE=""
            FILEBODY=${YMD_HMS}_${NAME}\(${STATION}\)_${STOP}
            FILEBODY=`php -r "echo substr(\"${FILEBODY}\", 0, 210);"`
            FILE=$DIR/${FILEBODY}
        else
            NAME=""
            CMDTITLE=""
            FILE=$DIR/${YMD_HMS}_${STATION}_${STOP}
        fi
    elif [ $# = 2 ]; then
        # ファイル名指定有り
        if [ -n "${PGNAME}" ]; then
            NAME="${PGNAME}"
            CMDTITLE="$2"
            FILEBODY=${YMD_HMS}_${NAME}\(${STATION}\)_${STOP}
            FILEBODY=`php -r "echo substr(\"${FILEBODY}\", 0, 210);"`
            FILE=$DIR/${FILEBODY}
        else
            NAME="$2"
            CMDTITLE="$2"
            FILEBODY=${YMD_HMS}_${NAME}\(${STATION}\)_${STOP}
            FILEBODY=`php -r "echo substr(\"${FILEBODY}\", 0, 210);"`
            FILE=$DIR/${FILEBODY}
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
    MP4="${FILE}.mp4"
    MP4S+=("$MP4")
    MP3="${FILE}.mp3"
    MP3S+=("$MP3")

    echo 'now date :' $RUN_DATE
    #echo 'run_s    :' $run_s
    #echo 'now_s    :' $now_s
    echo 'delay    :' $delay
    echo 'STOP     :' $STOP
    echo 'YMD      :' $YMD
    echo 'DIR      :' $DIR
    echo 'MP4      :' $MP4
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
while [ $RETVAL1 != 0 ]; do
    echo -n rec start :
    date
    create_filename "$@"
    echo "REC_CNT = $REC_CNT"
    echo ''

    rec $STOP "$MP4"
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

declare -i LOOP_MAX="${#MP4S[@]}"
declare -i LOOP_CNT=0
MAX='101'
MIN='97'
echo LOOP_MAX=$LOOP_MAX
while [ $LOOP_CNT -lt $LOOP_MAX ]; do
    echo LOOP_CNT=$LOOP_CNT

    MP4FILE="${MP4S[$LOOP_CNT]}"
    MP3FILE="${MP3S[$LOOP_CNT]}"
    echo "$MP4FILE"
    echo "$MP3FILE"
    MP4FILESIZE=''
    MP3FILESIZE=''
    ENC_START=''
    ENC_END=''

    if [ -f "$MP4FILE" ]; then
        MP4FILESIZE=`ls -lh "$MP4FILE" | awk '{print $5}'`

        # ffmpeg mp4 -> mp3
        if [ $RETVAL1 = 0 ]; then
            echo -n 'ffmpeg mp4 -> mp3 start : '
            date
            ENC_START=`date +%s`
            /usr/local/bin/ffmpeg \
              -y -i "$MP4FILE"    \
              -metadata StreamTitle="${NAME} ${JYMD_HM} ～ ${REC_MIN}分${REC_SEC}秒" \
              -metadata author="超A&G+"    \
              -metadata artist=${PGPRLTY}  \
              -metadata title="${PGNAME}"  \
              -metadata album="${PGTITLE}" \
              -metadata genre="ラジオ"     \
              -metadata year="${YEAR}"     \
              -metadata date="${YEAR}"     \
              -metadata comment="超A&G+
${JYMD_HM} ～ ${REC_MIN}分${REC_SEC}秒
番組タイトル  : ${PGTITLE}
パーソナリティ: ${PGPRLTY}
${NAME}
${CMDTITLE}" \
              -vn -acodec libmp3lame -ar 22050 -q:a 8 \
              "$MP3FILE"

            RETVAL2=$?
            echo "ffmpeg RETVAL2 = $RETVAL2"
            echo -n 'ffmpeg mp4 -> mp3 end   : '
            MP3FILESIZE=`ls -lh "$MP3FILE" | awk '{print $5}'`
            date
            ENC_END=`date +%s`
            echo ''
        fi

        MP4_SIZE=`ls -l "$MP4FILE" | awk '{ print $5}'`
        MP3_SIZE=`ls -l "$MP3FILE" | awk '{ print $5}'`
        MP3_RATE=`perl -e "printf(\"%d\n\", ($MP3_SIZE / $MP4_SIZE * 100) + 0.5);"`
        echo MAX=$MAX  MIN=$MIN
        echo MP3_RATE=$MP3_RATE  MP4_SIZE=$MP4_SIZE  MP3_SIZE=$MP3_SIZE

        echo "エンコード結果
LOOP_CNT / LOOP_MAX: ${LOOP_CNT} / ${LOOP_MAX}
終了時間: `date '+%Y/%m/%d %H:%M:%S'`
エンコード時間 : `expr $ENC_END - $ENC_START`
番組名  : ${PGNAME}
引数    : ${CMDTITLE}
MP4FILE : `basename "${MP4FILE}"` : ${MP4FILESIZE}
MP3FILE : `basename "${MP3FILE}"` : ${MP3FILESIZE}
MP3 RATE: $MP3_RATE :  MAX=$MAX  MIN=$MIN " | ~/bin/slack_agqr.sh -h "エンコード結果: $$"
    fi
    LOOP_CNT=$LOOP_CNT+1
done

if [ $RETVAL1 != 0 ]; then
    exit 2
fi

#vim: ts=4:sw=4

