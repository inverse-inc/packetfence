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
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <string.h>
#include "syslog.h"

int get_udp_socket(char* host, char* port, int* fd, struct sockaddr_storage* addr, int* addrlen)
{
    int sockfd, rc = 0;
    struct addrinfo hints, *servinfo = NULL, *p = NULL;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    rc = getaddrinfo(host, port, &hints, &servinfo);
    if (rc != 0) {
        return errno;
    }

    for (p = servinfo; p != NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype,
                             p->ai_protocol)) == -1) {
            continue;
        }

        memcpy(addr, p->ai_addr, p->ai_addrlen);
        *addrlen = p->ai_addrlen;
        *fd = sockfd;
        break;
    }

    if (p == NULL) {
        rc = errno;
    }

    free(servinfo);
    return rc;
}

#define CHECK(c)                 \
    do {                         \
        int tt = (int)(c);       \
        if ((buf - (tt)) >= end) \
            goto done;           \
    } while (0)

#define APPEND_STR(str, len)                             \
    do {                                                 \
        char* t = (str);                                 \
        int left_over = end - buf;                       \
        int to_copy = len > left_over ? left_over : len; \
        memcpy(buf, str, to_copy);                       \
        buf += to_copy;                                  \
    } while (0)

#define APPEND_INT(num) buf = buf + snprintf(buf, end - buf, "%d", num)
int format_syslog_msg(char* buf, size_t buf_len, struct syslog_header* header, char* timestamp, char* message, int msg_length)
{
    char* start = buf;
    char* end = buf + buf_len;
    CHECK(5);
    *buf++ = '<';
    APPEND_INT((header->facility << 3) | header->priority);
    *buf++ = '>';
    APPEND_STR(timestamp, strlen(timestamp));
    *buf++ = ' ';
    APPEND_STR(header->host, strlen(header->host));
    *buf++ = ' ';
    APPEND_STR(header->app, strlen(header->app));
    if (header->pid > 0) {
        *buf++ = '[';
        APPEND_INT(header->pid);
        *buf++ = ']';
    }
    *buf++ = ':';
    *buf++ = ' ';
    APPEND_STR(message, msg_length);

done:
    return buf - start;
}

int format_cef_value(char* buf, size_t buf_len, char* value, int len)
{
    char* start = buf;
    char* end = buf + buf_len;
    int i;
    for (i = 0; i < len && buf < end; i++) {
        switch (value[i]) {
        case '\n':
            CHECK(2);
            *buf++ = '\\';
            *buf++ = 'n';
            break;
        case '\r':
            CHECK(2);
            *buf++ = '\\';
            *buf++ = 'r';
            break;
        case '\\':
        case '=':
            CHECK(2);
            *buf++ = '\\';
        default:
            *buf++ = value[i];
            break;
        }
    }

done:
    return buf - start;
}

int format_cef_header(char* buf, size_t buf_len, char* value)
{
    char* start = buf;
    char* end = buf + buf_len;
    int len = strlen(value);
    int i;
    for (i = 0; i < len && buf < end; i++) {
        switch (value[i]) {
        case '\\':
        case '|':
            CHECK(2);
            *buf++ = '\\';
        default:
            *buf++ = value[i];
            break;
        }
    }

done:
    return buf - start;
}

int format_cef(struct cef_header* header, char* buf, size_t buf_len, char* name, char** args, unsigned long* lengths, int args_len)
{
    char* start = buf;
    char* end = buf + buf_len;
    int i;
    APPEND_STR("CEF:", 4);
    APPEND_INT(header->version);
    *buf++ = '|';
    buf += format_cef_header(buf, end - buf, header->deviceVendor);
    *buf++ = '|';
    buf += format_cef_header(buf, end - buf, header->deviceProduct);
    *buf++ = '|';
    buf += format_cef_header(buf, end - buf, header->deviceVersion);
    *buf++ = '|';
    buf += format_cef_header(buf, end - buf, header->deviceEventClassId);
    *buf++ = '|';
    buf += format_cef_header(buf, end - buf, name);
    *buf++ = '|';
    APPEND_INT(header->severity);
    *buf++ = '|';
    for (i = 0; i < args_len; i += 2) {
        if (i > 0) {
            *buf++ = ' ';
        }
        buf = buf + format_cef_value(buf, end - buf, args[i], lengths[i]);
        *buf++ = '=';
        buf = buf + format_cef_value(buf, end - buf, args[i + 1], lengths[i + 1]);
    }

done:
    return buf - start;
}

#undef CHECK
#undef APPEND_STR
#undef APPEND_INT
