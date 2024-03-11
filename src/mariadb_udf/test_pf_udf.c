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
#include <stdio.h>
#include <string.h>
#include "syslog.h"
#include "config.h"

#define TEST_TIMESTAMP "Aug 24 05:14:15"
#define TEST_HOST "test_host"
#define TEST_APP "app"
#define EXPECTED_CEF \
    "CEF:0|Inverse|PacketFence|10.2.9|ClassId|Name|0|bob=bob james=jame\\="
#define SYSLOG_HEADER "<14>" TEST_TIMESTAMP " " TEST_HOST " " TEST_APP "[2]: "
#define EXPECTED_MESSAGE SYSLOG_HEADER EXPECTED_CEF
#define CONFIG "type namespace facility priority port host"

void expected_string(char* got, char* expect)
{
    if (strcmp(got, expect) != 0) {
        printf("got '%s' expected '%s'\n", got, expect);
    }
}

int main(int argc, char** argv)
{
    int fd, len, rc;
    char syslog_buffer[1024] = { 0 };
    char cef_buffer[1024] = { 0 };
    struct sockaddr_storage saddr;
    struct sockaddr* addr = (struct sockaddr*)&saddr;
    char* args[] = { "bob", "bob", "james", "jame=", };
    unsigned long lengths[] = { 3, 3, 5, 5, };
    int addrlen;
    struct syslog_header syslog_header = {
        .facility = 1, .priority = 6, .pid = 2, .host = TEST_HOST, .app = TEST_APP,
    };
    struct cef_header cef_header = { .version = 0,
                                     .deviceVendor = "Inverse",
                                     .deviceProduct = "PacketFence",
                                     .deviceVersion = "10.2.9",
                                     .deviceEventClassId = "ClassId",
                                     .severity = 0, };
    struct configuration* configurations;
    int configuration_count;

    memset(&saddr, 0, sizeof(struct sockaddr_storage));
    rc = get_udp_socket("localhost", "514", &fd, &saddr, &addrlen);
    if (rc != 0) {
        printf("%d error returned\n", rc);
    }

    printf("fd %d, ip %d, port %d\n", fd,
           ((struct sockaddr_in*)addr)->sin_addr.s_addr,
           ((struct sockaddr_in*)addr)->sin_port);
    len = format_cef(&cef_header, cef_buffer, sizeof(cef_buffer), "Name", args,
                     lengths, sizeof(args) / sizeof(args[0]));
    expected_string(cef_buffer, EXPECTED_CEF);

    len = format_syslog_msg(syslog_buffer, sizeof(syslog_buffer), &syslog_header,
                            TEST_TIMESTAMP, cef_buffer, len);
    expected_string(syslog_buffer, EXPECTED_MESSAGE);
    printf("len %d\n", len);
    rc = sendto(fd, syslog_buffer, len, 0, addr, addrlen);
    printf("rc %d\n", rc);

    rc = priority_lookup("emerg", 5);
    if (rc != 0) {
        printf("Wrong priorioty %d\n", rc);
    }

    rc = loadconfig("/usr/local/pf/src/mariadb_udf/test_config",
                    &configuration_count, &configurations);
    if (rc != 0) {
        printf("Cannot load config %d error returned\n", rc);
    }

    if (configuration_count != 2) {
        printf("Configuration not loaded properly %d\n", configuration_count);
    }

    printf("%p %d\n", configurations, configuration_count);
    int i;
    for (i = 0; i < configuration_count; i++) {
        printf("%s\n", configurations[i].namespace);
    }

    return 0;
}
