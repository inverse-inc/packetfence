#!/usr/bin/env bash

MAX_CONCURRENCY="${MAX_CONCURRENCY:=10}"
MAX_EXEC_TIME="${MAX_EXEC_TIME:=60}"
PARALLEL="${PARALLEL:=10}"

mkfifo cfifo
exec 10<>cfifo && rm -f cfifo
for _ in $(seq 1 ${MAX_CONCURRENCY}); do { echo >&10; } done
for SLICE in $(seq 0 $(($PARALLEL-1))); do
    read -r -u10
    {
        CYPRESS_screenshotsFolder=cypress/results/screenshots/slice-${SLICE} \
        CYPRESS_videosFolder=cypress/results/videos/slice-${SLICE} \
        SLICE=${SLICE} \
        timeout ${MAX_EXEC_TIME} \
        $@

        [[ $? -ne 0 ]] && echo "Slice $SLICE timeout"

        echo >&10
    } &
done
wait
exec 10>&-
exec 10<&-
