#include "stdafx.h"
#include "acl.h"
/*#include <windows.h>
#include <tchar.h>
#include <stdio.h>*/
#include <tchar.h>

#define myheapalloc(x) (HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, x))
#define myheapfree(x)  (HeapFree(GetProcessHeap(), 0, x))

typedef BOOL (WINAPI *SetSecurityDescriptorControlFnPtr)(
   IN PSECURITY_DESCRIPTOR pSecurityDescriptor,
   IN SECURITY_DESCRIPTOR_CONTROL ControlBitsOfInterest,
   IN SECURITY_DESCRIPTOR_CONTROL ControlBitsToSet);

bool AddAccessRights(TCHAR *lpszFileName, TCHAR *lpszAccountName, 
      DWORD dwAccessMask) {

   // SID variables.
   SID_NAME_USE   snuType;
   TCHAR *        szDomain       = NULL;
   DWORD          cbDomain       = 0;
   LPVOID         pUserSID       = NULL;
   DWORD          cbUserSID      = 0;

   // File SD variables.
   PSECURITY_DESCRIPTOR pFileSD  = NULL;
   DWORD          cbFileSD       = 0;

   // New SD variables.
   SECURITY_DESCRIPTOR  newSD;

   // ACL variables.
   PACL           pACL           = NULL;
   BOOL           fDaclPresent;
   BOOL           fDaclDefaulted;
   ACL_SIZE_INFORMATION AclInfo;

   // New ACL variables.
   PACL           pNewACL        = NULL;
   DWORD          cbNewACL       = 0;

   // Temporary ACE.
   LPVOID         pTempAce       = NULL;
   UINT           CurrentAceIndex = 0;

   UINT           newAceIndex = 0;

   // Assume function will fail.
   BOOL           fResult        = FALSE;
   BOOL           fAPISuccess;

   SECURITY_INFORMATION secInfo = DACL_SECURITY_INFORMATION;

   // New APIs available only in Windows 2000 and above for setting 
   // SD control
   SetSecurityDescriptorControlFnPtr _SetSecurityDescriptorControl = NULL;

   __try {

      // 
      // STEP 1: Get SID of the account name specified.
      // 
      fAPISuccess = LookupAccountName(NULL, lpszAccountName,
            pUserSID, &cbUserSID, szDomain, &cbDomain, &snuType);

      // API should have failed with insufficient buffer.
      if (fAPISuccess)
         __leave;
      else if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
         writeMessageToLog(TEXT("LookupAccountName() failed. Error %d\n"), 
               GetLastError());
         __leave;
      }

      pUserSID = myheapalloc(cbUserSID);
      if (!pUserSID) {
         writeMessageToLog(TEXT("HeapAlloc() failed. Error %d\n"), GetLastError());
         __leave;
      }

      szDomain = (TCHAR *) myheapalloc(cbDomain * sizeof(TCHAR));
      if (!szDomain) {
         _tprintf(TEXT("HeapAlloc() failed. Error %d\n"), GetLastError());
         __leave;
      }

      fAPISuccess = LookupAccountName(NULL, lpszAccountName,
            pUserSID, &cbUserSID, szDomain, &cbDomain, &snuType);
      if (!fAPISuccess) {
         writeMessageToLog(TEXT("LookupAccountName() failed. Error %d\n"), 
               GetLastError());
         __leave;
      }

      // 
      // STEP 2: Get security descriptor (SD) of the file specified.
      // 
      fAPISuccess = GetFileSecurity(lpszFileName, 
            secInfo, pFileSD, 0, &cbFileSD);

      // API should have failed with insufficient buffer.
      if (fAPISuccess)
         __leave;
      else if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
         writeMessageToLog(TEXT("GetFileSecurity() failed. Error %d\n"), 
               GetLastError());
         __leave;
      }

      pFileSD = myheapalloc(cbFileSD);
      if (!pFileSD) {
         writeMessageToLog(TEXT("HeapAlloc() failed. Error %d\n"), GetLastError());
         __leave;
      }

      fAPISuccess = GetFileSecurity(lpszFileName, 
            secInfo, pFileSD, cbFileSD, &cbFileSD);
      if (!fAPISuccess) {
         writeMessageToLog(TEXT("GetFileSecurity() failed. Error %d\n"), 
               GetLastError());
         __leave;
      }

      // 
      // STEP 3: Initialize new SD.
      // 
      if (!InitializeSecurityDescriptor(&newSD, 
            SECURITY_DESCRIPTOR_REVISION)) {
         writeMessageToLog(TEXT("InitializeSecurityDescriptor() failed.")
            TEXT("Error %d\n"), GetLastError());
         __leave;
      }

      // 
      // STEP 4: Get DACL from the old SD.
      // 
      if (!GetSecurityDescriptorDacl(pFileSD, &fDaclPresent, &pACL,
            &fDaclDefaulted)) {
         writeMessageToLog(TEXT("GetSecurityDescriptorDacl() failed. Error %d\n"),
               GetLastError());
         __leave;
      }

      // 
      // STEP 5: Get size information for DACL.
      // 
      AclInfo.AceCount = 0; // Assume NULL DACL.
      AclInfo.AclBytesFree = 0;
      AclInfo.AclBytesInUse = sizeof(ACL);

      if (pACL == NULL)
         fDaclPresent = FALSE;

      // If not NULL DACL, gather size information from DACL.
      if (fDaclPresent) {    
         
         if (!GetAclInformation(pACL, &AclInfo, 
               sizeof(ACL_SIZE_INFORMATION), AclSizeInformation)) {
            writeMessageToLog(TEXT("GetAclInformation() failed. Error %d\n"),
                  GetLastError());
            __leave;
         }
      }

      // 
      // STEP 6: Compute size needed for the new ACL.
      // 
      cbNewACL = AclInfo.AclBytesInUse + sizeof(ACCESS_ALLOWED_ACE) 
            + GetLengthSid(pUserSID) - sizeof(DWORD);

      // 
      // STEP 7: Allocate memory for new ACL.
      // 
      pNewACL = (PACL) myheapalloc(cbNewACL);
      if (!pNewACL) {
         writeMessageToLog(TEXT("HeapAlloc() failed. Error %d\n"), GetLastError());
         __leave;
      }

      // 
      // STEP 8: Initialize the new ACL.
      // 
      if (!InitializeAcl(pNewACL, cbNewACL, ACL_REVISION2)) {
         writeMessageToLog(TEXT("InitializeAcl() failed. Error %d\n"), 
               GetLastError());
         __leave;
      }

      // 
      // STEP 9 If DACL is present, copy all the ACEs from the old DACL
      // to the new DACL.
      // 
      // The following code assumes that the old DACL is
      // already in Windows 2000 preferred order.  To conform 
      // to the new Windows 2000 preferred order, first we will 
      // copy all non-inherited ACEs from the old DACL to the 
      // new DACL, irrespective of the ACE type.
      // 
      
      newAceIndex = 0;

      if (fDaclPresent && AclInfo.AceCount) {

         for (CurrentAceIndex = 0; 
               CurrentAceIndex < AclInfo.AceCount;
               CurrentAceIndex++) {

            // 
            // STEP 10: Get an ACE.
            // 
            if (!GetAce(pACL, CurrentAceIndex, &pTempAce)) {
               writeMessageToLog(TEXT("GetAce() failed. Error %d\n"), 
                     GetLastError());
               __leave;
            }

            // 
            // STEP 11: Check if it is a non-inherited ACE.
            // If it is an inherited ACE, break from the loop so
            // that the new access allowed non-inherited ACE can
            // be added in the correct position, immediately after
            // all non-inherited ACEs.
            // 
            if (((ACCESS_ALLOWED_ACE *)pTempAce)->Header.AceFlags
               & INHERITED_ACE)
               break;

            // 
            // STEP 12: Skip adding the ACE, if the SID matches
            // with the account specified, as we are going to 
            // add an access allowed ACE with a different access 
            // mask.
            // 
            if (EqualSid(pUserSID,
               &(((ACCESS_ALLOWED_ACE *)pTempAce)->SidStart)))
               continue;

            // 
            // STEP 13: Add the ACE to the new ACL.
            // 
            if (!AddAce(pNewACL, ACL_REVISION, MAXDWORD, pTempAce,
                  ((PACE_HEADER) pTempAce)->AceSize)) {
               writeMessageToLog(TEXT("AddAce() failed. Error %d\n"), 
                     GetLastError());
               __leave;
            }

            newAceIndex++;
         }
      }

      // 
      // STEP 14: Add the access-allowed ACE to the new DACL.
      // The new ACE added here will be in the correct position,
      // immediately after all existing non-inherited ACEs.
      // 
      if (!AddAccessAllowedAce(pNewACL, ACL_REVISION2, dwAccessMask,
            pUserSID)) {
         writeMessageToLog(TEXT("AddAccessAllowedAce() failed. Error %d\n"),
               GetLastError());
         __leave;
      }

      // 
      // STEP 15: To conform to the new Windows 2000 preferred order,
      // we will now copy the rest of inherited ACEs from the
      // old DACL to the new DACL.
      // 
      if (fDaclPresent && AclInfo.AceCount) {

         for (; 
              CurrentAceIndex < AclInfo.AceCount;
              CurrentAceIndex++) {

            // 
            // STEP 16: Get an ACE.
            // 
            if (!GetAce(pACL, CurrentAceIndex, &pTempAce)) {
               writeMessageToLog(TEXT("GetAce() failed. Error %d\n"), 
                     GetLastError());
               __leave;
            }

            // 
            // STEP 17: Add the ACE to the new ACL.
            // 
            if (!AddAce(pNewACL, ACL_REVISION, MAXDWORD, pTempAce,
                  ((PACE_HEADER) pTempAce)->AceSize)) {
               writeMessageToLog(TEXT("AddAce() failed. Error %d\n"), 
                     GetLastError());
               __leave;
            }
         }
      }

      // 
      // STEP 18: Set the new DACL to the new SD.
      // 
      if (!SetSecurityDescriptorDacl(&newSD, TRUE, pNewACL, 
            FALSE)) {
         writeMessageToLog(TEXT("SetSecurityDescriptorDacl() failed. Error %d\n"),
               GetLastError());
         __leave;
      }

      // 
      // STEP 19: Copy the old security descriptor control flags 
      // regarding DACL automatic inheritance for Windows 2000 or 
      // later where SetSecurityDescriptorControl() API is available
      // in advapi32.dll.
      // 
      _SetSecurityDescriptorControl = (SetSecurityDescriptorControlFnPtr)
            GetProcAddress(GetModuleHandle(TEXT("advapi32.dll")),
            "SetSecurityDescriptorControl");
      if (_SetSecurityDescriptorControl) {

         SECURITY_DESCRIPTOR_CONTROL controlBitsOfInterest = 0;
         SECURITY_DESCRIPTOR_CONTROL controlBitsToSet = 0;
         SECURITY_DESCRIPTOR_CONTROL oldControlBits = 0;
         DWORD dwRevision = 0;

         if (!GetSecurityDescriptorControl(pFileSD, &oldControlBits,
            &dwRevision)) {
            writeMessageToLog(TEXT("GetSecurityDescriptorControl() failed.")
                  TEXT("Error %d\n"), GetLastError());
            __leave;
         }

         if (oldControlBits & SE_DACL_AUTO_INHERITED) {
            controlBitsOfInterest =
               SE_DACL_AUTO_INHERIT_REQ |
               SE_DACL_AUTO_INHERITED;
            controlBitsToSet = controlBitsOfInterest;
         }
         else if (oldControlBits & SE_DACL_PROTECTED) {
            controlBitsOfInterest = SE_DACL_PROTECTED;
            controlBitsToSet = controlBitsOfInterest;
         }
         
         if (controlBitsOfInterest) {
            if (!_SetSecurityDescriptorControl(&newSD,
               controlBitsOfInterest,
               controlBitsToSet)) {
               writeMessageToLog(TEXT("SetSecurityDescriptorControl() failed.")
                     TEXT("Error %d\n"), GetLastError());
               __leave;
            }
         }
      }

      // 
      // STEP 20: Set the new SD to the File.
      // 
      if (!SetFileSecurity(lpszFileName, secInfo,
            &newSD)) {
         writeMessageToLog(TEXT("SetFileSecurity() failed. Error %d\n"), 
               GetLastError());
         __leave;
      }

      fResult = TRUE;

   } __finally {

      // 
      // STEP 21: Free allocated memory
      // 
      if (pUserSID)
         myheapfree(pUserSID);

      if (szDomain)
         myheapfree(szDomain);

      if (pFileSD)
         myheapfree(pFileSD);

      if (pNewACL)
         myheapfree(pNewACL);
   }
   
   return fResult;
}

/*int _tmain(int argc, TCHAR *argv[]) {

   if (argc < 3) {
      _tprintf(TEXT("usage: \"%s\" <FileName> <AccountName>\n"), argv[0]);
      return 1;
   }

   // argv[1] - FileName
   // argv[2] - Name of the User or Group account to add access
   if (!AddAccessRights(argv[1], argv[2], GENERIC_ALL)) {
      _tprintf(TEXT("AddAccessRights() failed.\n"));
      return 1;
   }
   else {
      _tprintf(TEXT("AddAccessRights() succeeded.\n"));
      return 0;
   }
}*/


