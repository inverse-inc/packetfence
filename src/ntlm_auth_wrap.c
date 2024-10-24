/* A wrapper around ntlm_auth to log arguments and 
running time. 
WARNING: We cheat and do no bother to free memory allocated to strings here. 
The process is meant to be very short lived and never reused. */

/*  
  Copyright (C) 2005-2024 Inverse inc.
  
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
#include <argp.h>
#include <signal.h>
#include <curl/curl.h>
#include <cjson/cJSON.h>


const char *argp_program_version = "ntlm_auth_wrapper 1.0";
const char *argp_program_bug_address = "<info@inverse.ca>";

const int exit_code_no_error = 0;
const int exit_code_general_error = 1;
const int exit_code_network_error = 2;
const int exit_code_auth_failed = 3;
const int exit_code_api_error = 4;
const int exit_code_invalid_input = 5;


/* Program documentation. */
static char doc[] =
    "ntm_auth_wrapper: \tA performance logging wrapper for ntlm_auth";

/* A description of the arguments we accept. */
static char args_doc[] = "[arguments passed to ntlm_auth]";

/* The options we understand. */
static struct argp_option options[] = {
    {"host"       ,'h', "hostname or ip", 0, "StatsD host. Default is localhost."},
    {"port"       ,'p', "port", 0, "StatsD port. Default is 8125."},
    {"insecure"   ,'i', 0, 0, "Log insecure arguments such as the password."},
    {"nostatsd"   ,'s', 0, 0, "Don't send performance counters to statsd."},
    {"noresolv"   ,'n', 0, 0, "Do not resolve value for host and port."},
    {"log"        ,'l', 0, 0, "Send results to syslog."},
    {"logfacility",'f', "facility", 0, "Syslog facility. Default is local5."},
    {"loglevel"   ,'d', "level", 0, "Syslog level. Default is info."},
    {"api_host"   ,'a', "hostname/ip" ,0, "NTLM auth API host or IP" },
    {"api_port"   ,'t', "port" ,0, "NTLM auth API listening port" },
    {0}
};

/* Used by main to communicate with parse_opt. */
struct arguments {
    int insecure, nostatsd, noresolv, log, facility, level;
    char *host;
    char *port;
    char *api_host;
    char *api_port;
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
    case 'h':
        arguments->host = arg;
        break;
    case 'p':
        arguments->port = arg;
        break;
    case 'a':
        arguments->api_host = arg;
        break;
    case 't':
        arguments->api_port = arg;
        break;
    case 'f':
        if (strcasecmp(arg, "auth") == 0) {
            arguments->facility = LOG_AUTHPRIV;
        } else if (strcasecmp(arg, "authpriv") == 0) {
            arguments->facility = LOG_AUTHPRIV;
        } else if (strcasecmp(arg, "daemon") == 0) {
            arguments->facility = LOG_DAEMON;
        } else if (strcasecmp(arg, "user") == 0) {
            arguments->facility = LOG_USER;
        } else if (strcasecmp(arg, "local0") == 0) {
            arguments->facility = LOG_LOCAL0;
        } else if (strcasecmp(arg, "local1") == 0) {
            arguments->facility = LOG_LOCAL1;
        } else if (strcasecmp(arg, "local2") == 0) {
            arguments->facility = LOG_LOCAL2;
        } else if (strcasecmp(arg, "local3") == 0) {
            arguments->facility = LOG_LOCAL3;
        } else if (strcasecmp(arg, "local4") == 0) {
            arguments->facility = LOG_LOCAL4;
        } else if (strcasecmp(arg, "local5") == 0) {
            arguments->facility = LOG_LOCAL5;
        } else if (strcasecmp(arg, "local6") == 0) {
            arguments->facility = LOG_LOCAL6;
        } else if (strcasecmp(arg, "local7") == 0) {
            arguments->facility = LOG_LOCAL7;
        } else {
            return ARGP_ERR_UNKNOWN;
        }
        break;

    case 'd':
        if (strcasecmp(arg, "debug") == 0) {
            arguments->level = LOG_DEBUG;
        } else if (strcasecmp(arg, "notice") == 0) {
            arguments->level = LOG_NOTICE;
        } else if (strcasecmp(arg, "info") == 0) {
            arguments->level = LOG_INFO;
        } else if (strcasecmp(arg, "warning") == 0) {
            arguments->level = LOG_WARNING;
        } else if (strcasecmp(arg, "error") == 0) {
            arguments->level = LOG_ERR;
        } else if (strcasecmp(arg, "critical") == 0) {
            arguments->level = LOG_CRIT;
        } else if (strcasecmp(arg, "alert") == 0) {
            arguments->level = LOG_ALERT;
        } else if (strcasecmp(arg, "emerg") == 0) {
            arguments->level = LOG_ALERT;
        } else {
            return ARGP_ERR_UNKNOWN;
        }
        break;

    case ARGP_KEY_ARG:
        if (state->arg_num >= 32)
            /* Way too many arguments. */
            argp_usage(state);
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

// send results to syslog
void log_result(int argc, char **argv, const struct arguments args, int status, double elapsed)
{
    openlog("radius-debug", LOG_PID, args.facility);
    // build the log message
    char *log_msg;
    asprintf(&log_msg, "http://%s:%s", args.api_host, args.api_port);

    // concatenate the command with all argv args separated by sep
    int i = 1;
    while (i < argc ) {
        // split the argument on = and check the first part to reject excluded args.
        if (!args.insecure)
            if ((strncmp
                 (argv[i], "--password", strlen("--password")) == 0)
                ||
                (strncmp
                 (argv[i], "--challenge", strlen("--challenge")) == 0))
            {
                i=i+2; // will skip the next argument
                continue;
            }

        char *tmpstr = log_msg;
        log_msg = NULL;
        asprintf(&log_msg, "%s %s ", tmpstr, argv[i]);
        i++;
    }

    syslog(args.level, "%s time: %g ms, status: %i", log_msg, elapsed, status);
    closelog();
}

// send to statsd 
void send_statsd(const struct arguments args , int status, double elapsed)
{
    struct addrinfo *ailist;
    struct addrinfo hint;
    int sockfd, err;
    memset(&hint, 0, sizeof(hint));
    hint.ai_socktype = SOCK_DGRAM;
    hint.ai_family = AF_INET;
    if (args.noresolv)
        hint.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
    hint.ai_canonname = NULL;
    hint.ai_addr = NULL;
    hint.ai_next = NULL;
    if ((err = getaddrinfo(args.host, args.port, &hint, &ailist)) != 0) {
        sprintf("getaddrinfo error: %s", gai_strerror(err));
        return;
    }

    if ((sockfd = socket(ailist->ai_family, SOCK_DGRAM, 0)) < 0) {
        err = errno;
        fprintf(stderr, "cannot contact %s:%s: %s\n", args.host,
            args.port, strerror(err));
        return;
    }

    char *buf;

    asprintf(&buf, "ntlm_auth.time:%g|ms\n", elapsed);

    sendto(sockfd, buf, strlen(buf), 0, ailist->ai_addr, ailist->ai_addrlen);

    // increment counter if auth failed
    if (status == SIGTERM) {
        asprintf(&buf, "ntlm_auth.timeout:1|c\n");
        sendto(sockfd, buf, strlen(buf), 0, ailist->ai_addr, ailist->ai_addrlen);
    } else if (status > 0) {
        asprintf(&buf, "ntlm_auth.failures:1|c\n");
        sendto(sockfd, buf, strlen(buf), 0, ailist->ai_addr, ailist->ai_addrlen);
    }
    close(sockfd);
}

double howlong(struct timeval t1)
{
    struct timeval end;
    double elapsed;
    gettimeofday(&end, NULL);
    elapsed = (end.tv_sec - t1.tv_sec) * 1000.0;    // sec to ms
    elapsed += (end.tv_usec - t1.tv_usec) / 1000.0; // us to ms

    return elapsed;
}

struct MemoryStruct {
    char *memory;
    size_t size;
};

size_t write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    struct MemoryStruct *mem = (struct MemoryStruct *)userp;

    mem->memory = realloc(mem->memory, mem->size + realsize + 1);
    if (mem->memory == NULL) {
        printf("Not enough memory (realloc returned NULL)\n");
        return 0;
    }

    memcpy(&(mem->memory[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->memory[mem->size] = 0;

    return realsize;
}

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
    arguments.host = "localhost";
    arguments.port = "8125";
    arguments.facility = LOG_LOCAL5;
    arguments.level = LOG_INFO;
    arguments.api_host = "";
    arguments.api_port = "0";
    /* Parse our arguments; every option seen by parse_opt will
       be reflected in arguments. */
    argp_parse(&argp, argc, argv, 0, 0, &arguments);

    struct timeval t1;
    double elapsed;
    gettimeofday(&t1, NULL);

    // Find the -- separator if any and reset the argv accordingly
    // so it does not get passed to the execed program.
    int opt_end = 0;
    for (int i = 1; i < argc; i++) {
        if ((strncmp(argv[i], "--", strlen("--"))) == 0) {
            opt_end = i;
            break;
        }
    }
    if (opt_end) {
        // Here we move the pointer so that argv starts at opt_end
        // We also need to change argc to reflect discarding the wrapper arguments.
        // This can have consequences so pay attention.
        argv += opt_end;
        argc = argc - opt_end;
    }

    // keep the same values we used before, so SIGTERM = timeout, other non-zero values = auth error
    int status = 0;
    int exit_code = exit_code_no_error;

    if (strcmp(arguments.api_host, "") == 0 || strcmp(arguments.api_port, "0") == 0) {
        fprintf(stderr, "Error: missing NTLM auth API host or port settings.\n");
        fprintf(stderr, "This could happen if you previously manually joined this server to Windows AD.\n");
        fprintf(stderr, "If this is the case, you need to go to the admin UI, re-create the domain configuration.\n");

        exit(exit_code_invalid_input);
    }

    cJSON *json = cJSON_CreateObject();
    if (json == NULL) {
        fprintf(stderr, "Error: could not create JSON object. Exiting.");

        exit(exit_code_general_error);
    }

    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], "--username=", strlen("--username=")) == 0) {
            cJSON_AddStringToObject(json, "username", argv[i] + strlen("--username="));
        } else if (strncmp(argv[i], "--password=", strlen("--password=")) == 0) {
            cJSON_AddStringToObject(json, "password", argv[i] + strlen("--password="));
        } else if (strncmp(argv[i], "--request-nt-key", strlen("--request-nt-key")) == 0) {
            cJSON_AddItemToObject(json, "request-nt-key", cJSON_CreateTrue());
        } else if (strncmp(argv[i], "--challenge=", strlen("--challenge=")) == 0) {
            cJSON_AddStringToObject(json, "challenge", argv[i] + strlen("--challenge="));
        } else if (strncmp(argv[i], "--nt-response=", strlen("--nt-response=")) == 0) {
            cJSON_AddStringToObject(json, "nt-response", argv[i] + strlen("--nt-response="));
        } else if (strncmp(argv[i], "--mac=", strlen("--mac=")) == 0) {
            cJSON_AddStringToObject(json, "mac", argv[i] + strlen("--mac="));
        } else if (strncmp(argv[i], "--domain=", strlen("--domain=")) == 0) {
            cJSON_AddStringToObject(json, "domain", argv[i] + strlen("--domain="));
        }
    }

    char *json_string = cJSON_Print(json);
    CURL *curl;
    CURLcode cURLCode;
    struct MemoryStruct chunk;

    curl = curl_easy_init();
    chunk.memory = malloc(1);
    chunk.size = 0;
    if(curl) {
        char* uri;

        asprintf(&uri, "http://%s:%s/ntlm/auth", arguments.api_host, arguments.api_port);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &chunk);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, 2500L);

        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "POST");
        curl_easy_setopt(curl, CURLOPT_URL, uri);
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl, CURLOPT_DEFAULT_PROTOCOL, "https");

        struct curl_slist *headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_string);

        cURLCode = curl_easy_perform(curl);
        free(uri);

        if (cURLCode == CURLE_OK) {
            long http_response_code;
            curl_easy_getinfo(curl, CURLINFO_HTTP_CODE, &http_response_code);
            if (http_response_code == 200) {
                status = 0;
                exit_code = 0;
            } else {
                status = http_response_code;  // consider non-200 response as auth failures.
                exit_code = exit_code_general_error;
                if (400 <= http_response_code && http_response_code <= 499) {
                    exit_code = exit_code_auth_failed;
                }
                if (500 <= http_response_code && http_response_code <= 599) {
                    exit_code = exit_code_api_error;
                }
            }
            printf("%s\n", chunk.memory);
        } else {
            exit_code = exit_code_network_error;
            if (cURLCode==CURLE_OPERATION_TIMEDOUT || cURLCode == CURLE_COULDNT_RESOLVE_HOST || cURLCode == CURLE_COULDNT_CONNECT) {
                status = SIGTERM; // timeout / unreachable dest are considered as "network issues" (previously SIGTERM)
            } else {
                status = cURLCode;
            }
            fprintf(stderr, "exec curl failed: %s\n", curl_easy_strerror(cURLCode));
        }
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
    } else {
        exit_code = exit_code_general_error;
        fprintf(stderr, "Unable to initialize curl object.");
    }
    free(chunk.memory);
    free(json_string);
    cJSON_Delete(json);

    elapsed = howlong(t1);

    if (arguments.log)
        log_result(argc, argv, arguments, status, elapsed);
    // open socket to StatsD server and send message
    if (!arguments.nostatsd)
        send_statsd(arguments, status, elapsed);

    exit(exit_code);
}
