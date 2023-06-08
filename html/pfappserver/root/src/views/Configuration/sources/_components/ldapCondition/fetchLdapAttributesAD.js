import apiCall, {baseURL as apiBaseURL, baseURL} from '@/utils/api';
import _ from 'lodash';

function fetchLdapAttributesAD(serverId) {
  const performSearch = (filter=null, scope=null, attributes=null, base_dn=null) => {
    return apiCall.request({
      url: 'ldap/search',
      method: 'post',
      baseURL: (baseURL || baseURL === '') ? baseURL : apiBaseURL,
      data: {
        server: serverId,
        filter: filter,
        scope: scope,
        attributes: attributes,
        base_dn: base_dn,
      }
    })
  }

  var subSchemaDN = performSearch(null, "base", ["subschemaSubentry"], "")
    .then((response) => {
      var firstAttribute = response.data[Object.keys(response.data)[0]]
      return firstAttribute["subSchemaSubEntry"]
    })

  var attributes = subSchemaDN.then((dn) => {
    return performSearch("(objectclass=subschema)",
      "base",
      ["attributetypes"],
      dn)
      .then((response) => {
        return response.data[Object.keys(response.data)[0]]["attributeTypes"]
      })
  })

  return attributes.then((attributes) => {
    return extractAttributeNames(attributes)
  })
}

function extractAttributeNames(attributes) {
  return attributes.map((attribute) => {
    const properties = attribute.split(" ")
    return _.trim(properties[properties.indexOf("NAME") + 1], "'")
  })
}

export default fetchLdapAttributesAD
