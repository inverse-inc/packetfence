import _ from 'lodash';
import {
  sendLdapSearchRequest
} from '@/views/Configuration/sources/_components/ldapCondition/common';


function useAdLdap(form) {

  const performSearch = (filter, scope, attributes, base_dn) => {
    return sendLdapSearchRequest({...form.value}, filter, scope, attributes, base_dn)
  }

  const getSubSchemaDN = () => {
    return performSearch(null, 'base', ['subschemaSubentry'], '')
      .then((response) => {
        let firstAttribute = response.data[Object.keys(response.data)[0]]
        return firstAttribute['subSchemaSubEntry']
      })
  }

  const fetchAttributeTypes = (subSchemaDN) => {
    return performSearch('(objectclass=subschema)',
      'base',
      ['attributetypes'],
      subSchemaDN)
      .then((response) => {
        return response.data[Object.keys(response.data)[0]]['attributeTypes']
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
