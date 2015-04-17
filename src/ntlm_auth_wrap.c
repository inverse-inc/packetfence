/* A wrapper around ntlm_auth to log arguments and 
running time. 
WARNING: We cheat and do no bother to free memory allocated to strings here. 
The process is meant to be very short lived an never reused. */

/*  
  Copyright (C) 2015 Inverse inc.
  
  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
  USA.
*/

#define _POSIX_C_SOURCE 200809L
#define _GNU_SOURCE
#define MAX_STR_LENGTH 1023
#include <syslog.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#include <netdb.h>
#include <sys/socket.h>
#include "/root/apue.3e/include/apue.h"
#include <argp.h>

const char *argp_program_version = "ntlm_auth_wrapper 1.0";
const char *argp_program_bug_address = "<info@inverse.ca>";

/* Program documentation. */
static char doc[] = "ntm_auth_wrapper: \tA performance logging wrapper for ntlm_auth";

/* A description of the arguments we accept. */
static char args_doc[] = "[arguments passed to ntlm_auth]";

/* The options we understand. */
static struct argp_option options[] = {
	{"binary", 'b', "path", 0, "ntlm_auth binary path. Defaults to /usr/bin/ntlm_auth."},
	{"host", 'h', "hostname or ip", 0, "StatsD host. Default is localhost."},
	{"port", 'p', "port", 0, "StatsD port. Default is 8125."},
	{"insecure", 'i', 0, 0, "Log insecure arguments such as the password."},
	{"nostatsd", 's', 0, 0, "Don't send performance counters to statsd."},
	{"noresolv", 'n', 0, 0, "Do not resolve value for host and port."},
	{"log", 'l', 0, 0, "Send results to syslog."},
	{"logfacility", 'f', "facility", 0, "Syslog facility. Default is local5."},
	{"loglevel", 'd', "level", 0, "Syslog level. Default is info."},
	{0}
};

/* Used by main to communicate with parse_opt. */
struct arguments {
	int insecure, nostatsd, noresolv, log, facility, level;
	char *binary;
	char *host;
	char *port;
	char *args[];		// Arguments to ntlm_auth itself
};

/* Parse a single option. */
static error_t parse_opt(int key, char *arg, struct argp_state *state)
{
	/* Get the input argument from argp_parse, which we
	   know is a pointer to our arguments structure. */
	struct arguments *arguments = state->input;

	switch (key) {
	case 'i':
		arguments->insecure = 1;
		break;
	case 's':
		arguments->nostatsd = 1;
		break;
	case 'n':
		arguments->noresolv = 1;
		break;
	case 'l':
		arguments->log = 1;
		break;
	case 'b':
		arguments->binary = arg;
		break;
	case 'h':
		arguments->host = arg;
		break;
	case 'p':
		arguments->port = arg;
		break;
	case 'f':
		arguments->facility = arg;
		break;
	case 'd':
		arguments->level = arg;
		break;

	case ARGP_KEY_ARG:
		if (state->arg_num >= 8)
			/* Too many arguments. */
			argp_usage(state);

		arguments->args[state->arg_num] = arg;

		break;

	case ARGP_KEY_END:
		if (state->arg_num < 2)
			/* Not enough arguments. */
			argp_usage(state);
		break;

	default:
		return ARGP_ERR_UNKNOWN;
	}
	return 0;
}

/* Our argp parser. */
static struct argp argp = { options, parse_opt, args_doc, doc };

int main(argc, argv, envp)
int argc;
char **argv, **envp;
{

	/* Default values. */
	struct arguments arguments;
	arguments.insecure = 0;
	arguments.nostatsd = 0;
	arguments.noresolv = 0;
	arguments.log = 0;
	arguments.binary = "/usr/bin/ntlm_auth";
	arguments.host = "localhost";
	arguments.port = "8125";
	arguments.facility = LOG_LOCAL5;
	arguments.level = LOG_INFO;
	/* Parse our arguments; every option seen by parse_opt will
	   be reflected in arguments. */
	argp_parse(&argp, argc, argv, 0, 0, &arguments);

	struct timeval t1, t2;
	double elapsed;
	gettimeofday(&t1, NULL);

	// Fork a process, exec it and then wait for the exit.
	pid_t pid, ppid;
	ppid = getpid();

	int status;
	if ((pid = fork()) < 0) {
		perror(argv[0]);
		exit(1);
	} else if (pid == 0) {	// child
		// Find the -- separator if any and reset the argv accordingly
		// so it does not get passed to the execed program.
		int opt_end = 0;
		for (int i = 1; i < argc; i++) {
			if ((strncmp(argv[i], "--", strlen("--"))) == 0) {
				opt_end = i;
				break;
			}
		}
		if (opt_end)
			argv += opt_end;

		argv[0] = arguments.binary;
		execve(arguments.binary, argv, envp);
		perror(argv[0]);
		exit(1);
	}
	if (waitpid(pid, &status, 0) != pid) {	// wait for child
		perror(argv[0]);
		exit(1);
	}

	gettimeofday(&t2, NULL);
	elapsed = (t2.tv_sec - t1.tv_sec) * 1000.0;	// sec to ms
	elapsed += (t2.tv_usec - t1.tv_usec) / 1000.0;	// us to ms

	if (arguments.log) {
		openlog("radius-debug", LOG_PID, arguments.facility);
		// build the log message
		char *log_msg = arguments.binary;
		char *sep = " ";

		// concatenate the command with all argv args separated by sep
		for (int i = 1; i < argc; i++) {

			// truncate any string longer than MAX_STR_LENGTH + sep + \0
			int space_left =
			    (MAX_STR_LENGTH - (strlen(arguments.binary) + strlen(sep)));
			strncat(arguments.binary, sep, 1);
			strncat(arguments.binary, argv[i], space_left - 1);

			// split the argument on = and check the first part to reject excluded args.
			// skip the excluded args
			if ((strncmp(argv[i], "--password", strlen("--password")) == 0) ||
			    (strncmp(argv[i], "--challenge", strlen("--challenge")) == 0))
				continue;

			space_left = (MAX_STR_LENGTH - (strlen(log_msg) + strlen(sep)));
			strncat(log_msg, sep, 1);
			strncat(log_msg, argv[i], space_left - 1);

		}
		syslog(arguments.level, "%s time: %g ms, status: %i, exiting pid: %i", log_msg,
		       elapsed, WEXITSTATUS(status), ppid);
		closelog();
	}
	// open socket to StatsD server and send message
	struct addrinfo *ailist;
	struct addrinfo hint;
	int sockfd, err;
	memset(&hint, 0, sizeof(hint));
	hint.ai_socktype = SOCK_DGRAM;
	hint.ai_family = AF_INET;
	if (arguments.noresolv)
		hint.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
	//hint.ai_flags = NULL;
	hint.ai_canonname = NULL;
	hint.ai_addr = NULL;
	hint.ai_next = NULL;
	if ((err = getaddrinfo(arguments.host, arguments.port, &hint, &ailist)) != 0)
		sprintf("getaddrinfo error: %s", gai_strerror(err));

	if ((sockfd = socket(ailist->ai_family, SOCK_DGRAM, 0)) < 0) {
		err = errno;
		fprintf(stderr, "cannot contact %s: %s\n", "127.0.0.1:8125", strerror(err));
	} else {
		char *buf;
		char hostname[MAX_STR_LENGTH];
		gethostname(hostname, sizeof(hostname));
		connect(sockfd, ailist->ai_addr, ailist->ai_addrlen);

		asprintf(&buf, "%s.ntlm_auth.time:%g|ms\n", hostname, elapsed);

		send(sockfd, buf, strlen(buf), 0);

		// increment counter if auth failed
		if (status > 0) {
			asprintf(&buf, "%s.ntlm_auth.failures:1|c\n", hostname);
			send(sockfd, buf, strlen(buf), 0);
		}

	}

	exit(WEXITSTATUS(status));
}
