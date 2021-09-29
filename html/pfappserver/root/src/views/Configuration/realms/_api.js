import store from '@/store'
import apiCall from '@/utils/api'

const api = {
  search: data => {
    const singleTenant = store.state.session.tenant.id !== 0
    const tenants = (singleTenant)
      ? [store.state.session.tenant] // single-tenant mode
      : store.state.session.tenants // multi-tenant mode
    const promises = []
    tenants.forEach(tenant => {
      const headers = { 'X-PacketFence-Tenant-Id': tenant.id }
      const p = apiCall.post('config/realms/search', data, { headers })
        .then(response => {
          const { data: { items = [] } = {} } = response
          return { items: items.map(item => ({ ...item, tenant_id: tenant.id })) }
        })
        .catch(e => e) // ignore singular errors
      promises.push(p)
    })
    return Promise.all(promises)
      .then(responses => {
        return {
          items: responses.reduce((items, response) => {
            return [ ...items, ...response.items ]
          }, [])
        }
      })
  }
}

export default api

export const apiFactory = tenantId => {
  const headers = {
    'X-PacketFence-Tenant-Id': tenantId
  }
  return {
    ...api,
    list: params => {
      return apiCall.get('config/realms', { params, headers }).then(response => {
        return response.data
      })
    },
    listOptions: () => {
      return apiCall.options('config/realms', { headers }).then(response => {
        return response.data
      })
    },
    search: data => {
      return apiCall.post('config/realms/search', data, { headers }).then(response => {
        return response.data
      })
    },
    sortItems: items => {
      return apiCall.patch('config/realms/sort_items', items, { headers }).then(response => {
        return response
      })
    },
    create: item => {
      return apiCall.post('config/realms', item, { headers }).then(response => {
        return response.data
      })
    },
    item: id => {
      return apiCall.get(['config', 'realm', id], { headers }).then(response => {
        return response.data.item
      })
    },
    itemOptions: id => {
      return apiCall.options(['config', 'realm', id], { headers }).then(response => {
        return response.data
      })
    },
    update: item => {
      return apiCall.patch(['config', 'realm', item.id], item, { headers }).then(response => {
        return response.data
      })
    },
    delete: id => {
      return apiCall.delete(['config', 'realm', id], {}, { headers })
    }
  }
}
