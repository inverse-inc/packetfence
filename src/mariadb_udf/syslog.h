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
