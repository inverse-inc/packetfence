import apiCall from '@/utils/api'

export default {
  fingerbankDhcpFingerprints: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_fingerprints'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDhcpFingerprints: body => {
    return apiCall.post('fingerbank/all/dhcp_fingerprints/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDhcpFingerprint: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_fingerprint', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDhcpFingerprint: data => {
    return apiCall.post('fingerbank/local/dhcp_fingerprints', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDhcpFingerprint: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp_fingerprint', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDhcpFingerprint: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp_fingerprint', id])
  }
}
