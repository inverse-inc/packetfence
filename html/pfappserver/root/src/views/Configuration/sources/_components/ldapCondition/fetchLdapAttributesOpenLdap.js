import apiCall, {baseURL as apiBaseURL, baseURL} from '@/utils/api';

function fetchLdapAttributesOpenLdap(serverId) {
  return apiCall.request({
    url: 'ldap/search',
    method: 'post',
    baseURL: (baseURL || baseURL === '') ? baseURL : apiBaseURL,
    data: {
      server: serverId,
      search: "(objectclass=*)",
    }
  }).then((response) => {
    return responseToAttributes(response)
  })
}

function responseToAttributes(response) {
  console.log(response)
}

export default fetchLdapAttributesOpenLdap
