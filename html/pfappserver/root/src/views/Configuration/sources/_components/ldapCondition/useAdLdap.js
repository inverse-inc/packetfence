import apiCall, {baseURL as apiBaseURL, baseURL} from '@/utils/api';
import _ from 'lodash';


function useAdLdap(form) {

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
    ).then(response => {
      delete response.data.quiet;
      return response
    })
  }

  const getSubSchemaDN = () => {
    return performSearch(null, "base", ["subschemaSubentry"], "")
      .then((response) => {
        var firstAttribute = response.data[Object.keys(response.data)[0]]
        return firstAttribute["subSchemaSubEntry"]
      })
  }

  const fetchAttributeTypes = (subSchemaDN) => {
    return performSearch("(objectclass=subschema)",
      "base",
      ["attributetypes"],
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

  return {
    getAttributes: getAttributes,
    checkConnection: checkConnection,
    performSearch: performSearch
  }
}

function extractAttributeNames(attributes) {
  return attributes.map((attribute) => {
    const properties = attribute.split(" ")
    return _.trim(properties[properties.indexOf("NAME") + 1], "'")
  })
}

export default useAdLdap
