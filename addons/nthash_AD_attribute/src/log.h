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

#ifndef _LOG_H_
#define _LOG_H_

bool writeLog(wchar_t *message);
bool writeMessageToLog(wchar_t* format, ...);

#define LOG_FILE_NAME L"\\HashingPasswordFilter.log"
#define CHANGE_PASSWORD_MESSAGE L"Changed password for user \"%s\""
#define USER_INFO L"User information \"%s\" \"%s\""
#endif