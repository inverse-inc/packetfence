import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/connectors', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/connectors').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/connectors/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/connectors', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'connector', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'connector', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'connector', data.id], data).then(response => {
      return response.data
    })
  },
  sort: data => {
    return apiCall.patch('config/connectors/sort_items', data).then(response => {
      return response
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'connector', id])
  },
  status: () => {
    return apiCall.get('config/connectors/status').then(response => {
      return response.data
    })
  },
  equipment: id => {
    return apiCall.get(['config', 'connector', id, 'equipment']).then(response => {
      return response.data
    })
  },

  remoteStatus: id => {
    return apiCall.get(['pfconnector-remotes', id, 'status']).then(response => {
      return response.data
    })
  },
  topology: () => {
    return apiCall.get(['pfconnector-remotes', 'topology']).then(response => {
      return response.data
    })
  },
  traffic: (since, connector = null) => {
    const params = { since }
    if (connector)
      params.connector = connector
    return apiCall.get(['pfconnector-remotes', 'traffic'], { params }).then(response => {
      return response.data
    })
  },
  remoteRestart: id => {
    return apiCall.post(['pfconnector-remotes', id, 'restart']).then(response => {
      return response.data
    })
  },
  remoteUpgrade: id => {
    return apiCall.post(['pfconnector-remotes', id, 'upgrade']).then(response => {
      return response.data
    })
  },
  remoteInstall: (id, packages) => {
    return apiCall.post(['pfconnector-remotes', id, 'install'], { packages }).then(response => {
      return response.data
    })
  },
  remoteHaSwitch: (id, to) => {
    return apiCall.post(['pfconnector-remotes', id, 'ha', 'switch'], { to }).then(response => {
      return response.data
    })
  },
  dnsLookup: data => {
    return apiCall.post('pfconnector-remotes/dns-lookup', data).then(response => {
      return response.data
    })
  },
  forIp: ip => {
    return apiCall.getQuiet(['pfconnector-remotes', 'for-ip', ip]).then(response => {
      return response.data
    })
  },
  terminalSession: id => {
    return apiCall.post('terminal', { pfconnector_id: id }).then(response => {
      return response.data
    })
  },
  terminalAuthorize: (id, uuid, code) => {
    // The TOTP code travels in a header: query strings end up in access logs.
    return apiCall.get(['terminal', id, 'authorize', uuid], { headers: { 'X-PF-TOTP-Code': code || '' } }).then(response => {
      return response.data
    })
  }
}
