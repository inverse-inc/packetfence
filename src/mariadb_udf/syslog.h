#ifndef __PF_SYSLOG__
#define __PF_SYSLOG__
#include <netdb.h>

struct syslog_header {
    int facility;
    int priority;
    int pid;
    char* host;
    char* app;
};

struct cef_header {
    char* deviceVendor;
    char* deviceProduct;
    char* deviceVersion;
    char* deviceEventClassId;
    int severity;
    int version;
};

int get_udp_socket(char* host, char* port, int* fd, struct sockaddr_storage* addr, int* addr_len);

int format_syslog_msg(char* buf, size_t buf_len, struct syslog_header* header, char* timestamp, char* message, int msg_length);

int format_cef(struct cef_header* header, char* buf, size_t buf_len, char* name, char** args, unsigned long* lengths, int args_len);
#endif
