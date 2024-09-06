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
#define _GNU_SOURCE
#include <string.h>
#include "config.h"
#include <unistd.h>
#include <stdio.h>
#include <errno.h>

struct Lookup {
    char* name;
    int val;
};

int cleanup_cef_header(struct cef_header* header);

int cleanup_syslog_header(struct syslog_header* header)
{
    free(header->host);
    free(header->app);
}

// Lookup using binary search;
int _lookup(char* name, ssize_t name_len, struct Lookup* lookup, int len)
{
    int low = 0;
    while (len) {
        int mid = low + len / 2;
        int cmp = strncmp(name, lookup[mid].name, name_len);
        if (cmp == 0) {
            return lookup[mid].val;
        } else if (cmp > 0) {
            low = mid + 1;
            len--;
        }

        len >>= 1;
    }

    return -1;
}

int setup_syslog_header(struct syslog_header* header, char* line, ssize_t len);

int setup_cef_header(struct cef_header* header, char* line, ssize_t len);

// Must be sorted by name
static struct Lookup PRIORITY_LOOKUP[] = {
    { "alert", 1 },
    { "crit", 2 },
    { "debug", 7 },
    { "emerg", 0 },
    { "err", 3 },
    { "info", 6 },
    { "notice", 5 },
    { "warning", 4 },
};

// Must be sorted by name
static struct Lookup FACILITY_LOOKUP[] = {
    { "auth", 4 }, // Security/authentication messages
    { "authpriv", 10 }, // Security/authentication messages
    { "console", 14 }, // Log alert
    { "cron", 9 }, // Clock daemon
    { "daemon", 3 }, // System daemons
    { "ftp", 11 }, // FTP daemon
    { "kern", 0 }, // Kernel messages
    { "kernel", 0 }, // Kernel messages
    { "local0", 16 }, // Locally used facility
    { "local1", 17 }, // Locally used facility
    { "local2", 18 }, // Locally used facility
    { "local3", 19 }, // Locally used facility
    { "local4", 20 }, // Locally used facility
    { "local5", 21 }, // Locally used facility
    { "local6", 22 }, // Locally used facility
    { "local7", 23 }, // Locally used facility
    { "lpr", 6 }, // Line printer subsystem
    { "mail", 2 }, // Mail system
    { "news", 7 }, // Network news subsystem
    { "ntp", 12 }, // NTP subsystem
    { "security", 13 }, // Log audit
    { "solaris-cron", 15 }, // Scheduling daemon
    { "syslog", 5 }, // Messages generated internally by syslogd
    { "user", 1 }, // User-level messages
    { "uucp", 8 }, // UUCP subsystem
};

int priority_lookup(char* name, ssize_t len)
{
    return _lookup(name, len, PRIORITY_LOOKUP, sizeof(PRIORITY_LOOKUP) / sizeof(PRIORITY_LOOKUP[0]));
}

int facility_lookup(char* name, ssize_t len)
{
    return _lookup(name, len, FACILITY_LOOKUP, sizeof(FACILITY_LOOKUP) / sizeof(FACILITY_LOOKUP[0]));
}

#define get_val(f, v, l)               \
    do {                               \
        char* tmp;                     \
        char* field = (char*)memmem(line, len, f, strlen(f)); \
        v = NULL;                      \
        if (field == NULL) {           \
            break;                     \
        }                              \
        v = strchr(field, '=');        \
        v++;                           \
        tmp = strchr(v, ' ');          \
        if (tmp == NULL) {             \
            tmp = end;                 \
        }                              \
        val_len = tmp - v;             \
    } while (0)

// All resources that are acquired during first load.
// This can change if a threadsafe cleanup routine can be hooked into.
int loadconfig(char* path, int* count, struct configuration** out)
{
    FILE* fp;
    char host[256];
    char port[256];
    char* line = NULL, *end;
    size_t len;
    ssize_t read;
    struct configuration* configurations = NULL;
    int conf_len = 0;
    int rc = 0;

    fp = fopen(path, "r");
    if (fp == NULL) {
        return errno;
    }

    while ((read = getline(&line, &len, fp)) != -1) {
        char* value;
        ssize_t val_len;
        struct configuration conf;
        memset(&conf, 0, sizeof(struct configuration));
        if (line[0] == '#' || len < 3) {
            continue;
        }

        // Chomp off the end
        if (line[read - 1] == '\n') {
            read--;
        }

        end = line + read;
        get_val("type=", value, val_len);
        // Check for a valid type
        if (value == NULL || strncmp("syslog", value, val_len) != 0) {
            continue;
        }

        rc = setup_syslog_header(&conf.syslog_header, line, read);
        if (rc != 0) {
            continue;
        }

        rc = setup_cef_header(&conf.cef_header, line, read);
        if (rc != 0) {
            continue;
        }

        get_val("host=", value, val_len);
        if (value == NULL) {
            cleanup_syslog_header(&conf.syslog_header);
            cleanup_cef_header(&conf.cef_header);
            continue;
        }

        strncpy(host, value, val_len);
        host[val_len] = 0;

        get_val("port=", value, val_len);
        if (value == NULL) {
            cleanup_syslog_header(&conf.syslog_header);
            cleanup_cef_header(&conf.cef_header);
            continue;
        }

        strncpy(port, value, val_len);
        port[val_len] = 0;
        // The socket is never closed
        rc = get_udp_socket(host, port, &conf.syslog_fd, (struct sockaddr_storage*)&conf.saddr, &conf.saddr_len);
        if (rc != 0) {
            cleanup_syslog_header(&conf.syslog_header);
            cleanup_cef_header(&conf.cef_header);
            continue;
        }

        get_val("namespaces=", value, val_len);
        if (value == NULL) {
            cleanup_syslog_header(&conf.syslog_header);
            cleanup_cef_header(&conf.cef_header);
            continue;
        }

        while (value < end) {
            char* tmp = memchr(value, ',', end - value);
            if (tmp == NULL) {
                tmp = end;
            }

            val_len = tmp - value;
            conf_len++;
            // This memory is never freed
            configurations = realloc(configurations, sizeof(struct configuration) * conf_len);
            configurations[conf_len - 1] = conf;
            configurations[conf_len - 1].namespace = strndup(value, val_len);
            value = tmp + 1;
        }
    }

    if (ferror(fp)) {
        rc = errno;
    }

    if (line == NULL) {
        free(line);
    }

    fclose(fp);

    if (configurations != NULL) {
        *out = configurations;
        *count = conf_len;
    }

    return rc;
}

int cleanup_cef_header(struct cef_header* header)
{
    free(header->deviceVendor);
    free(header->deviceProduct);
    free(header->deviceVersion);
}

int setup_syslog_header(struct syslog_header* header, char* line, ssize_t len)
{
    char* end = line + len;
    char* value;
    ssize_t val_len;
    get_val("facility=", value, val_len);
    if (value == NULL) {
        return -1;
    }

    header->facility = facility_lookup(value, val_len);
    if (header->facility == -1) {
        return -1;
    }

    get_val("priority=", value, val_len);
    if (value == NULL) {
        return -1;
    }

    header->priority = priority_lookup(value, val_len);
    if (header->priority == -1) {
        return -1;
    }

    get_val("host_syslog=", value, val_len);
    if (value == NULL) {
        return -1;
    }

    header->host = strndup(value, val_len);

    get_val("app_syslog=", value, val_len);
    if (value == NULL) {
        return -1;
    }

    header->app = strndup(value, val_len);
    header->pid = getpid();
    return 0;
}

int setup_cef_header(struct cef_header* header, char* line, ssize_t len)
{
    char* end = line + len;
    char* value;
    ssize_t val_len;
    get_val("version_pf=", value, val_len);
    if (value == NULL) {
        return -1;
    }

    header->deviceVersion = strndup(value, val_len);
    header->deviceVendor = strdup("Inverse");
    header->deviceProduct = strdup("PacketFence");
    header->deviceEventClassId = "";
    header->severity = 0;
    header->version = 0;
    return 0;
}
