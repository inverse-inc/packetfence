import apiCall from '@/utils/api'

export default {
  fingerbankDhcpv6Fingerprints: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_fingerprints'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDhcpv6Fingerprints: body => {
    return apiCall.post('fingerbank/all/dhcp6_fingerprints/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDhcpv6Fingerprint: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_fingerprint', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDhcpv6Fingerprint: data => {
    return apiCall.post('fingerbank/local/dhcp6_fingerprints', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDhcpv6Fingerprint: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp6_fingerprint', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDhcpv6Fingerprint: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp6_fingerprint', id])
  }
}
