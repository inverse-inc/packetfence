import _ from 'lodash';
import {
  extractAttributeFromFilter,
  isAttributeDn,
  parseLdapResponseToAttributeArray,
  searchDn,
  sendLdapSearchRequest
} from '@/views/Configuration/sources/_components/ldapCondition/common';


function useAdLdap(form) {

  const performSearch = (filter, scope, attributes, base_dn) => {
    let server = { ...form.value }
    return sendLdapSearchRequest(server, filter, scope, attributes, base_dn)
      .then((result) => {
          if (_.isEmpty(result)) {
            return isAttributeDn(server, filter, scope, attributes, base_dn).then((isDn) => {
              if (isDn) {
                // In case there are a lot of results we can't know for sure if all DNs were found
                return searchDn(server, filter, scope, attributes, base_dn).then(([results, success]) => {
                  return {results: results, success: success}
                })
              } else {
                return {results: [], success: true}
              }
            })
          } else {
            return {
              results: parseLdapResponseToAttributeArray(result, extractAttributeFromFilter(filter)),
              success: true
            }
          }
        }
      )
  }

  const getSubSchemaDN = () => {
    return sendLdapSearchRequest({...form.value}, null, 'base', ['subschemaSubentry'], '')
      .then((result) => {
        let firstAttribute = result[Object.keys(result)[0]]
        return firstAttribute['subSchemaSubEntry']
      })
  }

  const fetchAttributeTypes = (subSchemaDN) => {
    return sendLdapSearchRequest({...form.value}, '(objectclass=subschema)',
      'base',
      ['attributetypes'],
      subSchemaDN)
      .then((response) => {
        const keys = Object.keys(response)
        if (keys.length) {
          const { attributeTypes } =  response[keys[0]]
          return attributeTypes
        }
        return []
      })
  }

  const getAttributes = () => {
    return getSubSchemaDN()
      .then((subSchemaDN) => {
        return fetchAttributeTypes(subSchemaDN)
      })
      .then((attributeTypes) => {
        return extractAttributeNames(attributeTypes)
      })
  }

  const checkConnection = () => {
    return getSubSchemaDN().then(() => true).catch(() => false)
  }

  return {
    getAttributes: getAttributes,
    checkConnection: checkConnection,
    performSearch: performSearch
  }
}

function extractAttributeNames(attributes) {
  return attributes.map((attribute) => {
    const properties = attribute.split(' ')
    return _.trim(properties[properties.indexOf('NAME') + 1], '\'')
  })
}

export default useAdLdap
