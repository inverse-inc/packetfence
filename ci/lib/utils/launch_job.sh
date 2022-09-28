#!/bin/sh
#
# A stupid script to launch an arbitrary process and wait for it to complete,
# yet detect when some bozo sends SIGKILL to the original process and
# pass along notification to the child via SIGHUP.
#
# Copyright (C) 2019 Global Satellite Engineering
#                    daniel@gsat.us
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# Usage: $0 <your script or program> [<your args>[<your args>...]]

launch_job() {
    parent=$1
    shift
    "$@" &
    child=$!
    for s in HUP INT QUIT TERM EXIT ALRM ABRT; do
	trap "trap - $s; kill -s $s $child $$" $s
    done

    # Check once per second if parent process was zapped or child process has
    # exited.
    while sleep 1; do
	# On parent process MIA, SIGHUP to self.
	[ -e /proc/$parent ] || kill -s HUP $$

	# Upon child termination we want its exit code.
	if [ ! -e /proc/$child ]; then
	    wait $child
    	    trap - HUP INT QUIT TERM EXIT ALRM ABRT
	    exit $?
	fi
    done
}

# Child process will survive SIGKILL of main process.
launch_job $$ "$@" &

# Main process will disappear if SIGKILLed and exit normally otherwise.
wait $!
