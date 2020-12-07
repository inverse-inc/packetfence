#ifndef __PF_UDF_CONFIG__
#define __PF_UDF_CONFIG__
#include <stdlib.h>
#include "syslog.h"

struct configuration {
    char* namespace;
    int syslog_fd;
    int saddr_len;
    struct sockaddr_storage saddr;
    struct cef_header cef_header;
    struct syslog_header syslog_header;
};

int loadconfig(char* path, int* count, struct configuration** out);
int priority_lookup(char* name, ssize_t len);
int facility_lookup(char* name, ssize_t len);

#endif
