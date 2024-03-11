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
