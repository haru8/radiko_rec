#/bin/bash

PROCESS_NAME="ffmpeg.*m3u8"
DELAY_TIME=300
PID=$$

for i in `ps -ef | grep "$PROCESS_NAME" | grep -v $PID | grep -v grep | awk '{print $2}'`
do

    TIME=`ps -o lstart --noheader -p $i`
    CMD_ARG=`ps -o cmd --noheader -p $i`
    #echo "$CMD_ARG"

    if [ -n "$TIME" ] && [ -n "$CMD_ARG" ]; then
        STAY_TIME=`echo "$CMD_ARG" | sed 's/^.*-t //;s/\([0-9]*\).*$/\1/'`
        STARTUP_TIME=`date +%s -d "$TIME"`
        END_TIME=`expr $STARTUP_TIME + $STAY_TIME + $DELAY_TIME`
        CURRENT_TIME=`date +%s`

        if [ $CURRENT_TIME -gt $END_TIME ]; then
            echo "$CMD_ARG"
            echo "kill $i"
            kill $i
        fi
    fi

done

