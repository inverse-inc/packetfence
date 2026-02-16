import trim from 'lodash/trim';
import {
  extractAttributeFromFilter,
  parseLdapResponseToAttributeArray,
  parseLdapStringToArray,
  sendLdapSearchRequest
} from '@/views/Configuration/sources/_components/ldapCondition/common';


function useOpenLdap(form) {

  const performSearch = (filter, scope, attributes, base_dn) => {
    return sendLdapSearchRequest({...form.value}, filter, scope, attributes, base_dn, 1000)
      .then((result) => {
          return {results: parseLdapResponseToAttributeArray(result, extractAttributeFromFilter(filter)), success: true}
        }
      )
  }

  const getSubSchemaDN = () => {
    return sendLdapSearchRequest({...form.value}, null, 'base', ['subSchemaSubEntry'], '', 1)
      .then((response) => {
        const keys = Object.keys(response)
        if (keys.length) {
          const firstAttribute = response[keys[0]]
          const lowerCaseKeys = Object.keys(firstAttribute).map(key => key.toLowerCase())
          const subSchemaSubEntryIndex = lowerCaseKeys.indexOf('subschemasubentry')
          if (subSchemaSubEntryIndex !== -1) {
            const subSchemaSubEntryKey = Object.keys(firstAttribute)[subSchemaSubEntryIndex]
            return firstAttribute[subSchemaSubEntryKey]
          }
        }
        return []
      })
  }

  const fetchAttributeTypes = (subSchemaDN) => {
    return sendLdapSearchRequest({...form.value}, '(objectClass=subSchema)', 'base', ['attributeTypes'], subSchemaDN, 1000)
      .then((response) => {
        const keys = Object.keys(response)
        if (keys.length) {
          const firstAttribute = response[keys[0]]
          const lowerCaseKeys = Object.keys(firstAttribute).map(key => key.toLowerCase())
          const attributeTypesIndex = lowerCaseKeys.indexOf('attributetypes')
          if (attributeTypesIndex !== -1) {
            const attributeTypesKey = Object.keys(firstAttribute)[attributeTypesIndex]
            return firstAttribute[attributeTypesKey]
          }
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
  let attributeNames = []
  attributes.forEach((attribute) => {
    const properties = attribute.split(' ')
    const attributeName = properties[properties.indexOf('NAME') + 1]
    if (attributeName === '(') {
      attributeNames.push(...extractAttributeNameAliases(properties))
    } else {
      attributeNames.push(trim(attributeName, '\''))
    }
  })
  return attributeNames
}

function extractAttributeNameAliases(attributeProperties) {
  const attributeStartIndex = attributeProperties.indexOf('NAME') + 1
  attributeProperties = attributeProperties.slice(attributeStartIndex)
  attributeProperties = attributeProperties.slice(0, attributeProperties.indexOf(')') + 1)
  const attributeString = attributeProperties.join(' ')

  return parseLdapStringToArray(attributeString).map((item) => trim(item, '\''))
}

export default useOpenLdap
