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

#ifndef _HASH_FILTER_H_
#define _HASH_FILTER_H_
struct Configuration{
    //DN and password of user to log to Active directory
    wchar_t* ldapAdminBindDn;
    wchar_t* ldapAdminPasswd;
    //LDAP query to used to find users
    wchar_t* ldapSearchBaseDn;
    //user and password of local account used to run the sync program
    wchar_t* processUser;
    //LDAP Attribute that contain the NTHASH
	wchar_t* ntHashAttribute;
	//LDAP server
	wchar_t* ldapServer;


};
extern Configuration configuration;

#endif