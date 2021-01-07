import apiCall from '@/utils/api'

export default {
  realms: (tenantId, params) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.get('config/realms', { params, headers }).then(response => {
      return response.data
    })
  },
  realmsOptions: () => {
    return apiCall.options('config/realms').then(response => {
      return response.data
    })
  },
  realm: (tenantId, id) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.get(['config', 'realm', id], { headers }).then(response => {
      return response.data.item
    })
  },
  realmOptions: (tenantId, id) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.options(['config', 'realm', id], { headers }).then(response => {
      return response.data
    })
  },
  createRealm: (tenantId, item) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.post('config/realms', item, { headers }).then(response => {
      return response.data
    })
  },
  updateRealm: (tenantId, item) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.patch(['config', 'realm', item.id], item, { headers }).then(response => {
      return response.data
    })
  },
  deleteRealm: (tenantId, id) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.delete(['config', 'realm', id], { headers })
  },
  sortRealms: (tenantId, items) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.patch('config/realms/sort_items', items, { headers }).then(response => {
      return response
    })
  }
}
