/* A wrapper around ntlm_auth to log arguments and 
running time */

#define COMMAND "/usr/bin/ntlm_auth"
#define MAX_STR_LENGTH 1023
#include <syslog.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/time.h>

int main(argc,argv,envp) int argc; char **argv, **envp;
{
    struct timeval t1, t2;
    double elapsed;
    char cmd[ MAX_STR_LENGTH + 1 ] = COMMAND;
    char *sep = " ";
    int ret = 1 ; // return code


    openlog("radius-debug", LOG_PID, LOG_LOCAL4);

    // concatenate the command with all argv args separated by sep
    int i;
    for (i = 1; i < argc; i++){
        // truncate any string longer than MAX_STR_LENGTH + sep + \0
        int space_left  = ( MAX_STR_LENGTH - ( strlen(cmd) + strlen(sep)) ); 
        strncat(cmd, sep, 1);
        strncat(cmd,argv[i], space_left - 1 );
    }

    gettimeofday(&t1, NULL);
    ret = system(cmd);

    gettimeofday(&t2, NULL);
    elapsed = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
    elapsed += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms

    syslog(LOG_INFO, "%s time: %g ms", cmd, elapsed);
    closelog();

    exit(ret);
}
