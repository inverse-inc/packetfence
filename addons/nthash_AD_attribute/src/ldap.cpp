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

LDAP* connect();
wchar_t* findUserDn(LDAP* ldap, wchar_t* user);
bool setHash(LDAP* ldap, wchar_t* dn, wchar_t* hash);

//this method tries to modify the password hash inside the AD entry of the given user
//username is the name of the user
//passwordHash is the hashed password
//returns true if successfull, false otherwise
bool writeHashToLdap(wchar_t *username,wchar_t *passwordHash)
{
    LDAP *ldap;
    bool result=TRUE;

    //tries to connect
    ldap=connect();
    if(ldap == NULL)
        return FALSE;

    //find the user distinguished name
    wchar_t* dn = findUserDn(ldap,username);
    if (dn != NULL){
        //if found write the hash
        result = setHash(ldap,dn,passwordHash);
        //and free the allocated memory
        ldap_memfreeW(dn);
    } else {
        result = FALSE;
    }
    
    //always free the resources
    ldap_unbind(ldap);
    return result; 

}

//this method tries to connect and bind to the AD server
//it returns a valid LDAP connection or NULL if there was problems
LDAP* connect()
{
    LDAP* ldap;
    ULONG status;
	wchar_t* ldapServerName = configuration.ldapServer;

    //initialize the connection
    ldap=ldap_init(ldapServerName, LDAP_PORT);
    if(ldap == NULL)
    {
        //on error log and return
        writeMessageToLog(L"Error during ldap_init: %s",ldap_err2string(LdapGetLastError()));
        return NULL;
    }

    //set the protocol version to 3
    int ldapVersion = LDAP_VERSION3;
    status=ldap_set_option(ldap, LDAP_OPT_PROTOCOL_VERSION, &ldapVersion );
    if(status != LDAP_SUCCESS)
    {
        //on error free resources, log and return
        writeMessageToLog(L"Error setting ldap version to 3: %s",ldap_err2string(status));
        ldap_unbind(ldap);
        return NULL;
    }

    //by setting this option, now you can also search from the AD root DN.
    //why does it works? It's a mistery... 
    //however, now you can use different OU without having a common root OU.
    status=ldap_set_option(ldap, LDAP_OPT_REFERRALS, LDAP_OPT_OFF);
    if(status != LDAP_SUCCESS)
    {
        //on error free resources, log and return
        writeMessageToLog(L"Error setting ldap referrals: %s",ldap_err2string(status));
        ldap_unbind(ldap);
        return NULL;
    }

    //try to bind user
    status=ldap_simple_bind_s(ldap, configuration.ldapAdminBindDn, configuration.ldapAdminPasswd);
    if(status != LDAP_SUCCESS)
    {
        //on error free resources, log and return
        writeMessageToLog(L"Error during ldap_simple_bind: %s",ldap_err2string(status));
        ldap_unbind(ldap);
        return NULL;
    }
    return ldap;
}

//helper functions that extracts the dn of an user entry only if it exists and is unique
//ldap is an active ladap connection
//searchHandle is a LDAPMessage containing the results of a query
//user is the name of the user searched, used only for logging
//return a string to be freed with ldap_memfree on succes or null on failure
wchar_t* handleSearchResult(LDAP* ldap, LDAPMessage* searchHandle, wchar_t* user){
    wchar_t* dn = NULL;
    LDAPMessage* searchResult;

    //check if found
    searchResult = ldap_first_entry(ldap, searchHandle);
    if(searchResult == NULL)
    {
        //on error log and return
        writeMessageToLog(L"Entry not found for user \"%s\"",user);
        return NULL;
    }

    //get the dn
    dn =ldap_get_dn(ldap, searchResult);
    if(dn == NULL)
    {
        //on error log and return
        writeMessageToLog(L"Could not retrieve the dn for user \"%s\"",user);
        return NULL;
    }


    //check uniqueness
    searchResult =ldap_next_entry(ldap, searchResult);
    if(searchResult != NULL)
    {
        //if duplicate free memory, log and return
        writeMessageToLog(L"Duplicate entry for user \"%s\"",user);
        ldap_memfree(dn);
        return NULL;
    }
    return dn;
}

//this functions extracts the dn of an user entry only if it exists and is unique
//ldap is an active ladap connection
//user is the name of the user searched
//return a string to be freed with ldap_memfree on succes or null on failure
wchar_t* findUserDn(LDAP* ldap, wchar_t* user)
{
    LDAPMessage* searchHandle = NULL;
    ULONG status;
    wchar_t* cn = NULL;
    wchar_t* dn = NULL;
    ULONG cnLength;


    //create string for query
    cnLength = _scwprintf(USER_SEARCH_QUERY,user) + 1;
    cn = (wchar_t*)malloc(cnLength * sizeof(wchar_t));
    swprintf(cn,cnLength,USER_SEARCH_QUERY,user);

    //start the query
    status=ldap_search_s(ldap, configuration.ldapSearchBaseDn, LDAP_SCOPE_SUBTREE, cn, NULL, false, &searchHandle);
    if(status == LDAP_SUCCESS){
        //if the query succeded handle the response
        dn = handleSearchResult(ldap,searchHandle,user);
    } 
	else{
		//else log
		writeMessageToLog(L"Error during quering %s: %s", cn, ldap_err2string(status));
    }

    //free the memory
    if (searchHandle != NULL)
        ldap_msgfree(searchHandle);
    if (cn != NULL)
        free(cn);

    //and return
    return dn;
}

//this function do the effective write of the hash in the AD entry
//ldap is an active ldap connection
//dn is the dn of the entry to modify
//hash is the password hash to write
//return true on succes or false on failure
bool setHash(LDAP* ldap, wchar_t* dn, wchar_t* hash)
{


    ULONG status;
    LDAPMod mod;
    //create the modification structure
    LDAPMod *mods[2]={&mod, NULL}; 

    wchar_t* values[2]={hash, NULL};

    mod.mod_op=LDAP_MOD_REPLACE;
	mod.mod_type = configuration.ntHashAttribute;
    mod.mod_vals.modv_strvals=values;

    //write
    status=ldap_modify_s(ldap, dn, mods);
    if(status == LDAP_SUCCESS){
        //on success return true
        return TRUE;
    } else {
        //on error log and return false
        writeMessageToLog(L"Error during the modification of the entry with dn= %s: %s",dn,ldap_err2string(status));
        return false;
    }
}
