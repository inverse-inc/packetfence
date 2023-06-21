import apiCall from '@/utils/api';
import _ from 'lodash';


function useOpenLdap(form) {

  const performSearch = (filter = null, scope = null, attributes = null, base_dn = null) => {
    return apiCall.postQuiet('ldap/search',
      {
        server: {
          ...form.value,
        },
        search_query: {
          filter: filter,
          scope: scope,
          attributes: attributes,
          base_dn: base_dn,
        }
      }
    ).then(response => {delete response.data.quiet; return response})
  }

  const getSubSchemaDN = () => {
    return performSearch(null, "base", ["subSchemaSubEntry"], form.value.basedn)
      .then((response) => {
        var firstAttribute = response.data[Object.keys(response.data)[0]]
        return firstAttribute["subschemaSubentry"]
      })
  }

  const fetchAttributeTypes = (subSchemaDN) => {
    return performSearch("(objectclass=subschema)",
      "base",
      ["attributeTypes"],
      subSchemaDN)
      .then((response) => {
        return response.data[Object.keys(response.data)[0]]["attributeTypes"]
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

  return {getAttributes: getAttributes, checkConnection: checkConnection}
}

function extractAttributeNames(attributes) {
  let attributeNames = []
  attributes.forEach((attribute) => {
    const properties = attribute.split(" ")
    const attributeName = properties[properties.indexOf("NAME") + 1]
    if(attributeName === "(") {
      attributeNames.push(...extractAttributeNameAliases(properties))
    } else {
      attributeNames.push(_.trim(attributeName, "'"))
    }
  })
  return attributeNames
}

function extractAttributeNameAliases(attributeProperties) {
  const aliases = []
  let currentAlias = ""

  for(let i = 1; i++;) {
    currentAlias = attributeProperties[attributeProperties.indexOf("NAME") + i]
    if(currentAlias === ")") {
      break
    }
    aliases.push(_.trim(currentAlias, "'"))
  }
  return aliases
}

export default useOpenLdap
