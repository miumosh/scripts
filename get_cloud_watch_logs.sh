#!/bin/bash

START_TIME="2024-04-20T00:00:00"
END_TIME="2024-05-30T23:59:59"
START_TIME_IN_MILLIS=$(date -d "$START_TIME" +%s%3N)
END_TIME_IN_MILLIS=$(date -d "$END_TIME" +%s%3N)

LOG_GROUP_NAME="/aws/rds/cluster/sbcntr-db/error"
LOG_STREAMS=($(aws logs describe-log-streams \
    --log-group-name $LOG_GROUP_NAME \
    --order-by LastEventTime \
    --descending \
    --query "logStreams[].logStreamName" \
    --output text))

for LOG_STREAM in ${LOG_STREAMS[@]}; do
    NEXT_TOKEN=""
    OUTPUT_FILE="${LOG_STREAM//\//_}.json"
    > $OUTPUT_FILE
    
    echo "Fetching logs from stream: $LOG_STREAM"
    
    while : ; do
        if [ -z "$NEXT_TOKEN" ]; then
            RESPONSE=$(aws logs filter-log-events \
                --log-group-name $LOG_GROUP_NAME \
                --log-stream-names $LOG_STREAM \
                --start-time $START_TIME_IN_MILLIS \
                --end-time $END_TIME_IN_MILLIS \
                --output json)
        else
            RESPONSE=$(aws logs filter-log-events \
                --log-group-name $LOG_GROUP_NAME \
                --log-stream-names $LOG_STREAM \
                --start-time $START_TIME_IN_MILLIS \
                --end-time $END_TIME_IN_MILLIS \
                --next-token $NEXT_TOKEN \
                --output json)
        fi
        
        echo "$RESPONSE" | jq -r '.events[].message' >> $OUTPUT_FILE
        
        NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.nextToken')
        if [ "$NEXT_TOKEN" == "null" ]; then
            break
        fi
    done
done
