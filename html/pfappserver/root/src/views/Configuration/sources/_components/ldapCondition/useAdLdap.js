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
    let server = {...form.value}
    // This also handles the case where we filter a DN attribute
    return sendLdapSearchRequest(server , filter, scope, attributes, base_dn)
        .then((result) => {
            if (_.isEmpty(result)) {
              return isAttributeDn(server, filter, scope, attributes, base_dn).then((isDn) => {
                if (isDn) {
                  return searchDn(server, filter, scope, attributes, base_dn)
                } else {
                  return []
                }
              })
            } else {
              return parseLdapResponseToAttributeArray(result, extractAttributeFromFilter(filter))
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
      .then((result) => {
        return result[Object.keys(result)[0]]['attributeTypes']
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
