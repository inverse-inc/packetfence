import apiCall from '@/utils/api'

const segments = path => `${path || ''}`.split('/').filter(segment => segment)

// replace {field} placeholders with the values of the item
export const interpolate = (path, item = {}) => `${path || ''}`.replace(/{([^}]+)}/g, (match, key) => (key in item) ? encodeURIComponent(item[key]) : match)

export default {
  // enabled admin UI plugins (conf/admin_ui_plugins.conf)
  plugins: () => {
    return apiCall.getQuiet('config/admin_ui_plugins/enabled').then(response => {
      return response.data.items
    })
  },
  // manifest served by the plugin itself
  manifest: plugin => {
    return apiCall.getQuiet(['plugins', plugin, 'admin-ui']).then(response => {
      return response.data
    })
  }
}

// CRUD of a collection of a plugin, following the PacketFence config API conventions
export const useCollectionApi = (plugin, collection) => {
  const base = ['plugins', plugin]
  const collectionPath = [...base, ...segments(collection.collection)]
  const resourcePath = [...base, ...segments(collection.resource || collection.collection)]
  return {
    list: params => {
      return apiCall.get(collectionPath, { params }).then(response => {
        return response.data
      })
    },
    listOptions: () => {
      return apiCall.options(collectionPath).then(response => {
        return response.data
      })
    },
    search: data => {
      return apiCall.post([...collectionPath, 'search'], data).then(response => {
        return response.data
      })
    },
    create: data => {
      return apiCall.post(collectionPath, data).then(response => {
        return response.data
      })
    },
    item: id => {
      return apiCall.get([...resourcePath, id]).then(response => {
        return response.data.item
      })
    },
    itemOptions: id => {
      return apiCall.options([...resourcePath, id]).then(response => {
        return response.data
      })
    },
    update: data => {
      return apiCall.patch([...resourcePath, data.id], data).then(response => {
        return response.data
      })
    },
    delete: id => {
      return apiCall.delete([...resourcePath, id])
    },
    status: () => {
      const { status: { endpoint } = {} } = collection
      if (!endpoint)
        return Promise.resolve({})
      return apiCall.getQuiet([...base, ...segments(endpoint)]).then(response => {
        return response.data
      })
    },
    action: (action, item) => {
      const { method = 'GET', endpoint } = action
      return apiCall.request({
        method: method.toLowerCase(),
        url: [...base, ...segments(interpolate(endpoint, item))].join('/'),
        data: (method.toUpperCase() === 'GET') ? undefined : item
      }).then(response => {
        return response.data
      })
    }
  }
}
