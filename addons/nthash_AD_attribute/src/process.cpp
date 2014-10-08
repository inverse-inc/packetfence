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
#include <Userenv.h>


void printError(wchar_t* prefix){
    wchar_t* message;
    FormatMessage( 

        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
        NULL,
        GetLastError(),
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
        (LPTSTR)&message,   //ugly bad design of this function if I ask to allocate the buffer 
                            //in reality I must pass a char** ???????
        0,
        NULL 
        );

    //log the error
    writeMessageToLog(prefix, message);

    //Free the buffer.
    LocalFree(message);

}

//helper functions that free the resource allocated to impersonate a user
void freeUserHandle(HANDLE userHandle,PROFILEINFO profileInfo, LPVOID envBlock){
    BOOL result;
    //if I created an environment block
    if (envBlock){
        //free it
        result = DestroyEnvironmentBlock(envBlock);
        if (!result)
            printError(L"Error during Environment block destroy: %s");
    }
    //I return to being myself
    result = RevertToSelf();
    if (!result)
        printError(L"Error during Revert to Self: %s");
    //If i loaded the profile
    if(profileInfo.hProfile){
        //unload it
        result = UnloadUserProfile(userHandle,profileInfo.hProfile);
        if (!result)
            printError(L"Error during Unload User profile: %s");
    }

    //if I opened a user Handle
    if(userHandle){
        //close it
        result = CloseHandle(userHandle);
        if (!result)
            printError(L"Error during Close Handle: %s");
    }
}

//helper function that prepares the ground for CreateProcesAsUser
bool getUserHandle(PHANDLE userHandle,LPPROFILEINFO profileInfo, LPVOID* envBlock, wchar_t* impersonatingUser, wchar_t* impersonatingPassword){
    PSID userSID = NULL;
    PVOID userProfile = NULL;
    DWORD userProfileSize = 0;
    QUOTA_LIMITS userQuota;
    //get a handle to a user
    BOOL result = LogonUserEx(impersonatingUser,L".",impersonatingPassword,LOGON32_LOGON_BATCH,LOGON32_PROVIDER_WINNT50,
        userHandle,&userSID,&userProfile,&userProfileSize,&userQuota);
    if (!result){
        printError(L"Error during LOgonUserEx: %s");
        return result;
    }

    memset(profileInfo,0,sizeof(PROFILEINFO));
    profileInfo->dwSize=sizeof(PROFILEINFO);
    profileInfo->lpUserName=impersonatingUser;
    //load the user profile in memory
    result = LoadUserProfile(*userHandle,profileInfo);
    if (!result){
        printError(L"Error during LoadUserProfile: %s");
        return result;
    }

    //impersonate the user
    result = ImpersonateLoggedOnUser(*userHandle);
    if (!result){
        printError(L"Error during ImpersonateLoggedOnUser: %s");
        return result;
    }

    //load in memory the environment block
    result = CreateEnvironmentBlock(envBlock,*userHandle,FALSE);
    if (!result){
        printError(L"Error during CreateEnvironmentBlock: %s");
        return result;
    }

    return TRUE;
}

//tiny wrapper around CreateProcesAsUser
bool executeProcessAsUser(HANDLE userHandle, LPVOID envBlock, wchar_t *userName,wchar_t *passwordHash){

    PROCESS_INFORMATION procInfo;
    memset(&procInfo,0,sizeof(procInfo));

    STARTUPINFO startInfo;
    memset(&startInfo,0,sizeof(startInfo));
    startInfo.cb = sizeof(startInfo);

    //prepare the command line
    //domain admin adminPassword 
    //user hash hashFunction
    int len = _scwprintf(configuration.processCommandLine,configuration.appsDomain,configuration.appsAdmin,
            configuration.appsPasswd,userName,passwordHash) + 1;
    wchar_t* buffer = (wchar_t*)malloc(len * sizeof(wchar_t));
    swprintf(buffer,len,configuration.processCommandLine,configuration.appsDomain,configuration.appsAdmin,
            configuration.appsPasswd,userName,passwordHash);

    //start the process
    startInfo.lpDesktop=L"";//win2003 bug if set to null the called application crashes, in theory it shouled work
                            //see http://kbalertz.com/960266/Error-message-CreateProcess-function-start-process-console-application-using-account-other-current-logon-account-Windows-Server.aspx
    bool result  = CreateProcessAsUser(userHandle,NULL,buffer,NULL,NULL,FALSE,CREATE_UNICODE_ENVIRONMENT,envBlock,NULL,&startInfo,&procInfo);
    if (!result)
        printError(L"Error during CreateProcessAsUser: %s");

    //free the command line
    free(buffer);
    return result;
}

bool sendHashToChildProcess(wchar_t *userName,wchar_t *passwordHash, wchar_t* impersonatingUser, wchar_t* impersonatingPassword){

    HANDLE userHandle = 0;
    PROFILEINFO profileInfo;
    LPVOID envBlock = 0;
    //get a handle to a user
    bool result = getUserHandle(&userHandle,&profileInfo,&envBlock,impersonatingUser,impersonatingPassword);

    //if succeeded
    if (result){
        //start child process as that user
        result = executeProcessAsUser(userHandle,envBlock,userName,passwordHash);
    }

    //always free the resources
    freeUserHandle(userHandle,profileInfo,envBlock);
    return result;
}

