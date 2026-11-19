import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/domains', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/domains').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'domain', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'domain', id]).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/domains', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'domain', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'domain', id])
  },
  test: id => {
    return apiCall.getQuiet(['config', 'domain', id, 'test_join']).then(response => {
      return response.data
    }).catch(err => {
      throw err
    })
  },
  search: data => {
    return apiCall.post('config/domains/search', data).then(response => {
      return response.data
    })
  },
  testMachineAccount: data => {
    const post = data.quiet ? 'postQuiet' : 'post'
    return apiCall[post]('ntlm/test', data).then(response => {
      return response.data
    }).catch(err=> {
      throw err
    })
  },
  // the connector that reaches an Active Directory server, and its NTLM
  // services (the Cloud Connectors section is the packetfence-plugin-pfconnector
  // plugin, the API of the connectors stays in PacketFence)
  connectorForIp: ip => {
    return apiCall.getQuiet(['pfconnector-remotes', 'for-ip', ip]).then(response => {
      return response.data
    })
  },
  connectorStatus: id => {
    return apiCall.get(['pfconnector-remotes', id, 'status']).then(response => {
      return response.data
    })
  },
  connectorInstall: (id, packages) => {
    return apiCall.post(['pfconnector-remotes', id, 'install'], { packages }).then(response => {
      return response.data
    })
  }
}
