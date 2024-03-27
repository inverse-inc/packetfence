import apiCall from '@/utils/api'

const api = {
  collections: params => {
    return apiCall.get('config/filter_engines', { params }).then(response => {
      return response.data
    })
  }
}

export default api

export const apiFactory = _collection => {
  const { collection, resource } = _collection
  return {
    ...api,
    list: params => {
      return apiCall.get(['config', 'filter_engines', collection], { params }).then(response => {
        return response.data
      }).catch(err => {
        throw err
      })
    },
    listOptions: params => {
      return apiCall.options(['config', 'filter_engines', collection], { params }).then(response => {
        return response.data
      })
    },
    create: data => {
      return apiCall.post(['config', 'filter_engines', collection], data).then(response => {
        return response.data
      })
    },
    sort: params => {
      const patch = params.quiet ? 'patchQuiet' : 'patch'
      return apiCall[patch](['config', 'filter_engines', collection, 'sort_items'], params).then(response => {
        return response.data
      })
    },
    search: params => {
      return apiCall.post(['config', 'filter_engines', collection, 'search'], params).then(response => {
        return response.data
      })
    },

    item: id => {
      return apiCall.get(['config', 'filter_engines', resource, id]).then(response => {
        return response.data.item
      }).catch(err => {
        throw err
      })
    },
    itemOptions: id => {
      return apiCall.options(['config', 'filter_engines', resource, id]).then(response => {
        return response.data
      })
    },
    update: data => {
      const patch = data.quiet ? 'patchQuiet' : 'patch'
      return apiCall[patch](['config', 'filter_engines', resource, data.id], data).then(response => {
        return response.data
      })
    },
    delete: id => {
      return apiCall.delete(['config', 'filter_engines', resource, id])
    }
  }
}
