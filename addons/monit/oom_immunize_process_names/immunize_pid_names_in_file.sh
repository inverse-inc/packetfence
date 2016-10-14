#!/bin/bash

#On recent systems (RHEL6+), oom_score_adj is the file to hit to immunize a process. A value of -1000 immunizes the PID , 1000 priorize the killing in the calculation of the actual score.
#For older systems (Kernel <2.6.32) the file is oom_adj. A value of -17 immunizes the PID, a value of 15 makes it one of the first to be killed.
OOM_FILE="oom_score_adj"
OOM_SCORE="-1000"

grep -Ev '(#.*$)|(^$)' process_names_to_immunize |while read name; do PIDS_TO_IMMUNIZE=$(pgrep -f $name); for PID_TO_IMMUNIZE in $PIDS_TO_IMMUNIZE; do if [ -e /proc/$PID_TO_IMMUNIZE/oom_adj ]; then echo $OOM_SCORE > /proc/$PID_TO_IMMUNIZE/$OOM_FILE; fi; done; done
