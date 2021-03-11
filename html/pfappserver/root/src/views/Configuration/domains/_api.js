import apiCall from '@/utils/api'

export default {
  domains: params => {
    return apiCall.get('config/domains', { params }).then(response => {
      return response.data
    })
  },
  domainsOptions: () => {
    return apiCall.options('config/domains').then(response => {
      return response.data
    })
  },
  domain: id => {
    return apiCall.get(['config', 'domain', id]).then(response => {
      return response.data.item
    })
  },
  domainOptions: id => {
    return apiCall.options(['config', 'domain', id]).then(response => {
      return response.data
    })
  },
  createDomain: data => {
    return apiCall.post('config/domains', data).then(response => {
      return response.data
    })
  },
  updateDomain: data => {
    return apiCall.patch(['config', 'domain', data.id], data).then(response => {
      return response.data
    })
  },
  deleteDomain: id => {
    return apiCall.delete(['config', 'domain', id])
  },
  testDomain: id => {
    return apiCall.getQuiet(['config', 'domain', id, 'test_join']).then(response => {
      return response.data
    }).catch(err => {
      throw err
    })
  },
  joinDomain: data => {
    return apiCall.post(['config', 'domain', data.id, 'join'], data).then(response => {
      return response.data
    })
  },
  rejoinDomain: data => {
    return apiCall.post(['config', 'domain', data.id, 'rejoin'], data).then(response => {
      return response.data
    })
  },
  unjoinDomain: data => {
    return apiCall.post(['config', 'domain', data.id, 'unjoin'], data).then(response => {
      return response.data
    })
  }
}
