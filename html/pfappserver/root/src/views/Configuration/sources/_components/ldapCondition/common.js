import apiCall from '@/utils/api'
import {intsToStrings} from '@/utils/convert'
import _ from 'lodash'

export const ldapFormsSupported = ['LDAP', 'AD', 'EDIR']

export const parseLdapStringToArray = (ldapString) => {
  const ldapArrayRegex = new RegExp('^[[(]')
  if (ldapArrayRegex.test(ldapString)) {
    return ldapString.split(' ')
      .filter((item) => !['[', ']', '(', ')'].includes(item))
  } else {
    return [ldapString]
  }
}

export const parseLdapResponseToAttributeArray = (ldapResponse, ldapAttribute) => {
  const ldapEntries = Object.values(ldapResponse)
  let parsedEntries = new Set()
  for (let i = 0; i < ldapEntries.length; i++) {
    let value = ldapEntries[i][ldapAttribute]
    if (Array.isArray(value)) {
      parsedEntries = new Set([...parsedEntries, ...value])
    } else {
      parsedEntries.add(value)
    }
  }
  return Array.from(parsedEntries).filter((item) => {
    return Boolean(item)
  })
}

export const extractAttributeFromFilter = (filter) => {
  let attribute = _.trim(filter.split('=')[0], '(')
  if (/^memberOf:([0-9.])+$/.test(attribute)) {
    return 'memberOf'
  }
  return attribute
}

const getAllAttributes = (server, filter, scope, base_dn, limit) => {
  let searchAttribute = extractAttributeFromFilter(filter)
  let allAttributeSearchQuery = `(${searchAttribute}=*)`
  return sendLdapSearchRequest(server, allAttributeSearchQuery,
    scope, [searchAttribute], base_dn, limit)
}

export const isAttributeDn = (server, filter, scope, base_dn) => {
  return getAllAttributes(server, filter, scope, base_dn).then((exampleEntry) => {
    if(_.isEmpty(exampleEntry)) {
      return false
    }
    exampleEntry = exampleEntry[Object.keys(exampleEntry)[0]]
    exampleEntry = exampleEntry[Object.keys(exampleEntry)[0]]
    if(Array.isArray(exampleEntry)) {
      exampleEntry = exampleEntry[0]
    }
    return (exampleEntry.search('=') !== -1 && exampleEntry.search(',') !== -1)
  })
}

export const searchDn = (server, filter, scope, base_dn) => {
  return getAllAttributes(server, filter, scope, base_dn).then((allEntries) => {
    let success = true
    // 1000 is the default limit for ldapsearch
    if (Object.keys(allEntries).length > 1000) {
      success = false
    }
    let attributeSet = new Set();
    for (let dn in allEntries) {
      let entry = allEntries[dn]
      let attribute = entry[Object.keys(entry)[0]]
      if(!Array.isArray(attribute)) attribute = [attribute]
      attribute.forEach((item) => attributeSet.add(item))
    }
    let regexQuery = new RegExp(_.trim(filter.split('=')[1], ')(*'), "i")
    return [[...attributeSet].filter((item) => regexQuery.test(item)), success]
  })
}

export const sendLdapSearchRequest = (server,
                                      filter = null,
                                      scope = null,
                                      attributes = null,
                                      base_dn = null,
                                      limit = 1E3) => {
  server = intsToStrings(server)
  return apiCall.postQuiet('ldap/search',
    {
      server: server,
      search_query: {
        filter: filter,
        scope: scope,
        attributes: attributes,
        base_dn: base_dn,
        size_limit: limit,
      }
    }
  ).then(response => {
    delete response.data.quiet;
    return response.data
  })
}
