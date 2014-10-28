/**
 *
 * Copyright (c) 2009 Mauri Marco All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
**/

#include "stdafx.h"
#include <shlobj.h>

wchar_t originaldll[]=LOG_FILE_NAME;

bool writeLog(wchar_t *message) {
	
	//get the system path
	wchar_t systempath[MAX_PATH + 1];
    if(!SUCCEEDED(SHGetFolderPath(NULL,CSIDL_COMMON_APPDATA|CSIDL_FLAG_CREATE, NULL, 0, systempath))) return false;

	wchar_t *totalpath=lstrcat(systempath,originaldll);
    if (totalpath == NULL) return false;
   
    SYSTEMTIME timestamp;
	GetSystemTime(&timestamp);
        
        unsigned int year=timestamp.wYear;
        unsigned int month=timestamp.wMonth;
        unsigned int day=timestamp.wDay;

        unsigned int hour=timestamp.wHour;
		unsigned int minute=timestamp.wMinute;
		unsigned int second=timestamp.wSecond;
		unsigned int milliseconds=timestamp.wMilliseconds;

   FILE* logFile=_wfopen( totalpath, L"a+b" );
   if (logFile==NULL)
       return FALSE;
   fwprintf(logFile,L"[%04u/%02u/%02u %02u:%02u:%02u:%03u]:%s\r\n",year,month,day,hour,minute,second,milliseconds,message);
   fclose(logFile);
   return TRUE;
}

bool writeMessageToLog(wchar_t* format, ...){
    va_list args;

    va_start( args, format );
    int len = _vscwprintf(format,args) + 1;
    wchar_t* buffer = (wchar_t*)malloc(len * sizeof(wchar_t));
    vswprintf(buffer,len,format,args);
    bool result = writeLog(buffer);
    free(buffer);
    return result;
}