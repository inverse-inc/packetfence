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
#include <mysql.h>
#include <string.h>
#include <pthread.h>
#include <stdlib.h>
#include "syslog.h"
#include "config.h"
#include <stdio.h>

static pthread_once_t CONFIGURATION_ONCE = PTHREAD_ONCE_INIT;

static struct configuration* configurations = NULL;
static int configurations_len = 0;

void setup_configuration(void)
{
    loadconfig("/usr/local/pf/var/conf/mariadb_pf_udf", &configurations_len, &configurations);
}

my_bool pf_logger_init(UDF_INIT* initid, UDF_ARGS* args, char* message)
{
    int i;
    if (args->arg_count < 3) {
        strcpy(message, "LOGGER(): must have at least 3 args");
        return 1;
    }

    if ((args->arg_count & 1) == 0) {
        sprintf(message, "LOGGER(): expects an odd number of arguements %d", args->arg_count);
        return 1;
    }

    pthread_once(&CONFIGURATION_ONCE, setup_configuration);
    for (i = 0; i < args->arg_count; i++) {
        args->arg_type[i] = STRING_RESULT;
    }

    initid->maybe_null = 0;
    return 0;
}

long long pf_logger(UDF_INIT* initid, UDF_ARGS* args, char* is_null, char* error)
{
    char syslog_buffer[1024] = { 0 };
    char cef_buffer[1024] = { 0 };
    int i, cef_len, syslog_len;
    *is_null = 0;
    *error = 0;

    for (i = 0; i < configurations_len; i++) {
        if (strncmp(configurations[i].namespace, args->args[0], args->lengths[0]) == 0) {
            memset(cef_buffer, 0, sizeof(cef_buffer));
            memset(syslog_buffer, 0, sizeof(syslog_buffer));
            cef_len = format_cef(&configurations[i].cef_header, cef_buffer, sizeof(cef_buffer), args->args[0], &args->args[1], &args->lengths[1], args->arg_count - 1);
            syslog_len = format_syslog_msg(syslog_buffer, sizeof(syslog_buffer), &configurations[i].syslog_header, "", cef_buffer, cef_len);
            sendto(configurations[i].syslog_fd, syslog_buffer, syslog_len, 0, (struct sockaddr*)&configurations[i].saddr, configurations[i].saddr_len);
        }
    }

    return 0;
}

void pf_logger_deinit(UDF_INIT* initid)
{
}
