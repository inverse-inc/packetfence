// stdafx.h : include file for standard system include files,
//  or project specific include files that are used frequently, but
//      are changed infrequently
//

#if !defined(AFX_STDAFX_H__B3732ECD_EF57_423E_AB87_FF45196F935B__INCLUDED_)
#define AFX_STDAFX_H__B3732ECD_EF57_423E_AB87_FF45196F935B__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000


// Insert your headers here
#define WIN32_LEAN_AND_MEAN		// Exclude rarely-used stuff from Windows headers
#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif
#include <windows.h>
#include <NtSecApi.h>
#include <stdio.h>
#include <stdlib.h>
#include <winldap.h>
#include "ldap.h"
#include "log.h"
#include "process.h"
#include "HashingPasswordFilter.h"


//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_STDAFX_H__B3732ECD_EF57_423E_AB87_FF45196F935B__INCLUDED_)
