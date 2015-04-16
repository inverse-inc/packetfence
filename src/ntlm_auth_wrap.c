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
#define COMMAND "/usr/bin/ntlm_auth"
#define MAX_STR_LENGTH 1023
#define STATSD_BUFLEN 128
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

int
main (argc, argv, envp)
     int argc;
     char **argv, **envp;
{
  struct timeval t1, t2;
  double elapsed;
  char cmd[MAX_STR_LENGTH + 1] = COMMAND;
  char log_msg[MAX_STR_LENGTH + 1] = COMMAND;
  char *sep = " ";

  openlog ("radius-debug", LOG_PID, LOG_LOCAL5);

  // concatenate the command with all argv args separated by sep
  for (int i = 1; i < argc; i++)
    {

      // truncate any string longer than MAX_STR_LENGTH + sep + \0
      int space_left = (MAX_STR_LENGTH - (strlen (cmd) + strlen (sep)));
      strncat (cmd, sep, 1);
      strncat (cmd, argv[i], space_left - 1);

      // split the argument on = and check the first part to reject excluded args.
      // skip the excluded args
      if ((strncmp (argv[i], "--password", strlen ("--password")) == 0) ||
	  (strncmp (argv[i], "--challenge", strlen ("--challenge")) == 0))
	continue;

      // build the log message
      space_left = (MAX_STR_LENGTH - (strlen (log_msg) + strlen (sep)));
      strncat (log_msg, sep, 1);
      strncat (log_msg, argv[i], space_left - 1);

    }

  gettimeofday (&t1, NULL);

  // Fork a process, exec it and then wait for the exit.
  pid_t pid, ppid;
  ppid = getpid ();

  int status;
  if ((pid = fork ()) < 0)
    {
      perror (argv[0]);
      exit (1);
    }
  else if (pid == 0)
    {				// child
      argv[0] = COMMAND;
      execve (COMMAND, argv, envp);
      perror (argv[0]);
      exit (1);
    }
  if (waitpid (pid, &status, 0) != pid)
    {				// wait for child
      perror (argv[0]);
      exit (1);
    }

  gettimeofday (&t2, NULL);
  elapsed = (t2.tv_sec - t1.tv_sec) * 1000.0;	// sec to ms
  elapsed += (t2.tv_usec - t1.tv_usec) / 1000.0;	// us to ms

  syslog (LOG_INFO, "%s time: %g ms, status: %i, exiting pid: %i", log_msg,
	  elapsed, WEXITSTATUS (status), ppid);
  closelog ();

  // open socket to StatsD server and send message
  struct addrinfo *ailist;
  struct addrinfo hint;
  int sockfd, err;
  memset (&hint, 0, sizeof (hint));
  hint.ai_socktype = SOCK_DGRAM;
  hint.ai_family = AF_INET;
  hint.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
  hint.ai_canonname = NULL;
  hint.ai_addr = NULL;
  hint.ai_next = NULL;
  if ((err = getaddrinfo ("127.0.0.1", "8125", &hint, &ailist)) != 0)
    sprintf ("getaddrinfo error: %s", gai_strerror (err));

  if ((sockfd = socket (ailist->ai_family, SOCK_DGRAM, 0)) < 0)
    {
      err = errno;
      fprintf (stderr, "cannot contact %s: %s\n", "127.0.0.1:8125",
	       strerror (err));
    }
  else
    {
      char *buf;
      char hostname[255];
      gethostname (hostname, sizeof (hostname));
      asprintf (&buf, "%s.ntlm_auth.time:%g|ms\n", hostname, elapsed);

      if (sendto (sockfd, buf, strlen (buf), 0, ailist->ai_addr, ailist->ai_addrlen) < 0)
	    fprintf (stderr, "sendto error");
    }

  exit (WEXITSTATUS (status));
}
