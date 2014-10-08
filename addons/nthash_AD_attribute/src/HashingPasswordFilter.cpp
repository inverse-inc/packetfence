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
#include "acl.h"
#include <shlobj.h>



   #ifndef STATUS_SUCCESS
   #define STATUS_SUCCESS                  ((NTSTATUS)0x00000000L)
   #define STATUS_OBJECT_NAME_NOT_FOUND    ((NTSTATUS)0xC0000034L)
   #define STATUS_INVALID_SID              ((NTSTATUS)0xC0000078L)
   #endif

#define INIT_A 0x67452301
#define INIT_B 0xefcdab89
#define INIT_C 0x98badcfe
#define INIT_D 0x10325476
#define SQRT_2 0x5a827999
#define SQRT_3 0x6ed9eba1

unsigned int nt_buffer[16];
unsigned int nt_buffer2[128];
unsigned int output[4];
char itoa16[17] = "0123456789ABCDEF";
char ntlmhash[33];
static HANDLE hlog;


CONST LPWSTR pBadProcess = L"HashPasswordFilter: Create Process Failed!!!";

BOOLEAN NTAPI InitializeChangeNotify();
NTSTATUS NTAPI PasswordChangeNotify(PUNICODE_STRING,ULONG,PUNICODE_STRING);
BOOLEAN NTAPI PasswordFilter(PUNICODE_STRING,PUNICODE_STRING,PUNICODE_STRING,BOOLEAN);

wchar_t* loadSetting(wchar_t* path,wchar_t* key,wchar_t* buffer, int bufferLen){
    int charRead = GetPrivateProfileString(L"Main",key,NULL,buffer,bufferLen,path);
    wchar_t* out =(wchar_t*) malloc((charRead + 1) * sizeof(wchar_t));
    wcscpy(out,buffer);
    return out;
}

bool loadConfig(){
    wchar_t inipath[MAX_PATH + 1];
    if(!SUCCEEDED(SHGetFolderPath(NULL,CSIDL_COMMON_APPDATA|CSIDL_FLAG_CREATE, NULL, 0, inipath))) return false;
    wchar_t* path = lstrcat(inipath,L"\\HashingPasswordFilter.ini");
    wchar_t buffer[MAX_PATH + 1];
    if (path==NULL)return false;
    configuration.ldapAdminBindDn = loadSetting(path,L"ldapAdminBindDn",buffer,MAX_PATH + 1);
    configuration.ldapAdminPasswd = loadSetting(path,L"ldapAdminPasswd",buffer,MAX_PATH + 1);
    configuration.ldapSearchBaseDn = loadSetting(path,L"ldapSearchBaseDn",buffer,MAX_PATH + 1);
	configuration.processUser = loadSetting(path, L"processUser", buffer, MAX_PATH + 1);
	configuration.ntHashAttribute = loadSetting(path, L"ntHashAttribute", buffer, MAX_PATH + 1);
    return true;
}

Configuration configuration;
bool configured = false;

wchar_t *GetWC(const char *c)
{
    const size_t cSize = strlen(c)+1;
    wchar_t* wc = new wchar_t[cSize];
    mbstowcs (wc, c, cSize);

    return wc;
}

void NTLM(LPSTR key, USHORT sizekey)
{
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Prepare the string for hash calculation
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	int i = 0;
	int j = 1;

    int length = sizekey;
	
	output[0] = INIT_A;
	output[1] = INIT_B;
	output[2] = INIT_C;
	output[3] = INIT_D;
		
	memset(nt_buffer, 0, 16*8);


	for (; i<length / 2; i++)
		nt_buffer2[i] = key[2 * i] | (key[2 * i + 1] << 16);

	//padding
	if (length % 2 == 1)
		nt_buffer2[i] = key[length - 1] | 0x800000;
	else
		nt_buffer2[i] = 0x80;
	//put the length

	int modulo = ((length + 5) / 2) / 16;

	nt_buffer2[16 + (modulo * 16) - 2] = length << 4;

	for (j = 0; j < modulo + 1; j++) {
		memset(nt_buffer, 0, 16 * 8);
		for (i = 0; i < 16; i++) {
			nt_buffer[i] = nt_buffer2[i + (j * 16)];
		}

		//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		// NTLM hash calculation
		//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		unsigned int a = output[0];
		unsigned int b = output[1];
		unsigned int c = output[2];
		unsigned int d = output[3];

		/* Round 1 */
		a += (d ^ (b & (c ^ d))) + nt_buffer[0]; a = (a << 3) | (a >> 29);
		d += (c ^ (a & (b ^ c))) + nt_buffer[1]; d = (d << 7) | (d >> 25);
		c += (b ^ (d & (a ^ b))) + nt_buffer[2]; c = (c << 11) | (c >> 21);
		b += (a ^ (c & (d ^ a))) + nt_buffer[3]; b = (b << 19) | (b >> 13);

		a += (d ^ (b & (c ^ d))) + nt_buffer[4]; a = (a << 3) | (a >> 29);
		d += (c ^ (a & (b ^ c))) + nt_buffer[5]; d = (d << 7) | (d >> 25);
		c += (b ^ (d & (a ^ b))) + nt_buffer[6]; c = (c << 11) | (c >> 21);
		b += (a ^ (c & (d ^ a))) + nt_buffer[7]; b = (b << 19) | (b >> 13);

		a += (d ^ (b & (c ^ d))) + nt_buffer[8]; a = (a << 3) | (a >> 29);
		d += (c ^ (a & (b ^ c))) + nt_buffer[9]; d = (d << 7) | (d >> 25);
		c += (b ^ (d & (a ^ b))) + nt_buffer[10]; c = (c << 11) | (c >> 21);
		b += (a ^ (c & (d ^ a))) + nt_buffer[11]; b = (b << 19) | (b >> 13);

		a += (d ^ (b & (c ^ d))) + nt_buffer[12]; a = (a << 3) | (a >> 29);
		d += (c ^ (a & (b ^ c))) + nt_buffer[13]; d = (d << 7) | (d >> 25);
		c += (b ^ (d & (a ^ b))) + nt_buffer[14]; c = (c << 11) | (c >> 21);
		b += (a ^ (c & (d ^ a))) + nt_buffer[15]; b = (b << 19) | (b >> 13);

		/* Round 2 */
		a += ((b & (c | d)) | (c & d)) + nt_buffer[0] + SQRT_2; a = (a << 3) | (a >> 29);
		d += ((a & (b | c)) | (b & c)) + nt_buffer[4] + SQRT_2; d = (d << 5) | (d >> 27);
		c += ((d & (a | b)) | (a & b)) + nt_buffer[8] + SQRT_2; c = (c << 9) | (c >> 23);
		b += ((c & (d | a)) | (d & a)) + nt_buffer[12] + SQRT_2; b = (b << 13) | (b >> 19);

		a += ((b & (c | d)) | (c & d)) + nt_buffer[1] + SQRT_2; a = (a << 3) | (a >> 29);
		d += ((a & (b | c)) | (b & c)) + nt_buffer[5] + SQRT_2; d = (d << 5) | (d >> 27);
		c += ((d & (a | b)) | (a & b)) + nt_buffer[9] + SQRT_2; c = (c << 9) | (c >> 23);
		b += ((c & (d | a)) | (d & a)) + nt_buffer[13] + SQRT_2; b = (b << 13) | (b >> 19);

		a += ((b & (c | d)) | (c & d)) + nt_buffer[2] + SQRT_2; a = (a << 3) | (a >> 29);
		d += ((a & (b | c)) | (b & c)) + nt_buffer[6] + SQRT_2; d = (d << 5) | (d >> 27);
		c += ((d & (a | b)) | (a & b)) + nt_buffer[10] + SQRT_2; c = (c << 9) | (c >> 23);
		b += ((c & (d | a)) | (d & a)) + nt_buffer[14] + SQRT_2; b = (b << 13) | (b >> 19);

		a += ((b & (c | d)) | (c & d)) + nt_buffer[3] + SQRT_2; a = (a << 3) | (a >> 29);
		d += ((a & (b | c)) | (b & c)) + nt_buffer[7] + SQRT_2; d = (d << 5) | (d >> 27);
		c += ((d & (a | b)) | (a & b)) + nt_buffer[11] + SQRT_2; c = (c << 9) | (c >> 23);
		b += ((c & (d | a)) | (d & a)) + nt_buffer[15] + SQRT_2; b = (b << 13) | (b >> 19);

		/* Round 3 */
		a += (d ^ c ^ b) + nt_buffer[0] + SQRT_3; a = (a << 3) | (a >> 29);
		d += (c ^ b ^ a) + nt_buffer[8] + SQRT_3; d = (d << 9) | (d >> 23);
		c += (b ^ a ^ d) + nt_buffer[4] + SQRT_3; c = (c << 11) | (c >> 21);
		b += (a ^ d ^ c) + nt_buffer[12] + SQRT_3; b = (b << 15) | (b >> 17);

		a += (d ^ c ^ b) + nt_buffer[2] + SQRT_3; a = (a << 3) | (a >> 29);
		d += (c ^ b ^ a) + nt_buffer[10] + SQRT_3; d = (d << 9) | (d >> 23);
		c += (b ^ a ^ d) + nt_buffer[6] + SQRT_3; c = (c << 11) | (c >> 21);
		b += (a ^ d ^ c) + nt_buffer[14] + SQRT_3; b = (b << 15) | (b >> 17);

		a += (d ^ c ^ b) + nt_buffer[1] + SQRT_3; a = (a << 3) | (a >> 29);
		d += (c ^ b ^ a) + nt_buffer[9] + SQRT_3; d = (d << 9) | (d >> 23);
		c += (b ^ a ^ d) + nt_buffer[5] + SQRT_3; c = (c << 11) | (c >> 21);
		b += (a ^ d ^ c) + nt_buffer[13] + SQRT_3; b = (b << 15) | (b >> 17);

		a += (d ^ c ^ b) + nt_buffer[3] + SQRT_3; a = (a << 3) | (a >> 29);
		d += (c ^ b ^ a) + nt_buffer[11] + SQRT_3; d = (d << 9) | (d >> 23);
		c += (b ^ a ^ d) + nt_buffer[7] + SQRT_3; c = (c << 11) | (c >> 21);
		b += (a ^ d ^ c) + nt_buffer[15] + SQRT_3; b = (b << 15) | (b >> 17);

		output[0] = a + output[0];
		output[1] = b + output[1];
		output[2] = c + output[2];
		output[3] = d + output[3];
	}

	//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Convert the hash to hex (for being readable)
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for(i=0; i<4; i++) {
        int j = 0;
        unsigned int n = output[i];
        //iterate the bytes of the integer 
        for(; j<4; j++) {
            unsigned int convert = n % 256;
            ntlmhash[i * 8 + j * 2 + 1] = itoa16[convert % 16];
            convert = convert / 16;
            ntlmhash[i * 8 + j * 2 + 0] = itoa16[convert % 16];
            n = n / 256;
        }   
    }
}
//**********************************************

bool setFilePermissions(){
    wchar_t systempath[MAX_PATH + 1];
    if(!SUCCEEDED(SHGetFolderPath(NULL,CSIDL_COMMON_APPDATA|CSIDL_FLAG_CREATE, NULL, 0, systempath))) return false;
    
    wchar_t originaldll[]=LOG_FILE_NAME;
	wchar_t *totalpath=lstrcat(systempath,originaldll);
    if (totalpath == NULL) return false;
    writeMessageToLog(L"Setting write permission for user %s", configuration.processUser); 
    bool result = AddAccessRights(totalpath,configuration.processUser, GENERIC_ALL);
    if (!result){
        writeMessageToLog(L"Unable to set write permission for user %s, the log could be incomplete from now on",configuration.processUser);
        return FALSE;
    } else {
        writeMessageToLog(L"Write permission for user %s set", configuration.processUser);
        return TRUE;
    }
}

bool initializeFilter(){
    bool result = loadConfig();
    return result;
}

BOOL APIENTRY DllMain( HANDLE hModule, 
                       DWORD  ul_reason_for_call, 
                       LPVOID lpReserved
					 )
{
	hlog = RegisterEventSource(NULL, L"HashingPasswordFilter.dll");
    return TRUE;
}


//no initialization necessary
BOOLEAN NTAPI InitializeChangeNotify()
{   

	writeLog(L"Starting HashingPasswordFilter");
    if (initializeFilter()){
        writeLog(L"HashingPasswordFilter initialized");
        return TRUE;
    } else {
        writeLog(L"HashingPasswordFilter: initialization failed");
        return FALSE;
    }

}


//the event: password has changed succesfully
NTSTATUS NTAPI PasswordChangeNotify(PUNICODE_STRING UserName,ULONG RelativeId,PUNICODE_STRING NewPassword)
{
	
	
    if (!configured){
        configured = setFilePermissions();
    }
	
	int nLen=0;
    bool result;
	BOOL bad = FALSE;

    //copy username
    int userLength = UserName->Length/ sizeof(wchar_t);
    wchar_t* username = (wchar_t*)malloc((userLength + 1) * sizeof(wchar_t));
    wchar_t* z = wcsncpy(username,UserName->Buffer,userLength);
    //set the last character to null
    username[userLength] = NULL;


	//convert the password from widechar to utf-8
	int passwordLength = NewPassword->Length / sizeof(wchar_t);
	nLen = WideCharToMultiByte(CP_UTF8, 0, NewPassword->Buffer, passwordLength, 0, 0, 0, 0);
	char* password = (char*)malloc((nLen + 1) * sizeof(char));
	nLen = WideCharToMultiByte(CP_UTF8, 0, NewPassword->Buffer, passwordLength, password, nLen, 0, 0);
	//set the last character to null
	password[nLen] = NULL;
	
	// writeMessageToLog(USER_INFO, username, password);

	NTLM(password, passwordLength);
    //try to write the hash to ldap

	result = writeHashToLdap(username,GetWC(ntlmhash));
    if (result){
        writeMessageToLog(CHANGE_PASSWORD_MESSAGE,username);
    }
    else
        writeMessageToLog(L"Change failed for user \"%s\"",username);


    //zero the password
    SecureZeroMemory(password,nLen);
    //free the memory
	free(username);
	free(password);

    
    //can I return something else in case of error?
	return STATUS_SUCCESS;

}

//don't apply any password policy
BOOLEAN NTAPI PasswordFilter(PUNICODE_STRING AccountName,PUNICODE_STRING FullName,PUNICODE_STRING Password,BOOLEAN SetOperation)
{

   return TRUE;

}


