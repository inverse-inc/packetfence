import apiCall from '@/utils/api'

export default {
  filterEnginesCollections: params => {
    return apiCall.get('config/filter_engines', { params }).then(response => {
      return response.data
    })
  },
  filterEnginesCollection: collection => {
    return apiCall.get(['config', 'filter_engines', collection], { params: { limit: 1000 } }).then(response => {
      return response.data
    }).catch(err => {
      throw err
    })
  },
  filterEngine: ({ resource, id }) => {
    return apiCall.get(['config', 'filter_engines', resource, id]).then(response => {
      return response.data.item
    }).catch(err => {
      throw err
    })
  },
  filterEnginesOptions: collection => {
    return apiCall.options(['config', 'filter_engines', collection]).then(response => {
      return response.data
    })
  },
  filterEngineOptions: ({ resource, id }) => {
    return apiCall.options(['config', 'filter_engines', resource, id]).then(response => {
      return response.data
    })
  },
  sortFilterEngines: ({ collection, params }) => {
    const patch = params.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'filter_engines', collection, 'sort_items'], params).then(response => {
      return response.data
    })
  },
  createFilterEngine: ({ collection, data }) => {
    return apiCall.post(['config', 'filter_engines', collection], data).then(response => {
      return response.data
    })
  },
  updateFilterEngine: ({ resource, id, data }) => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'filter_engines', resource, id], data).then(response => {
      return response.data
    })
  },
  deleteFilterEngine: ({ resource, id }) => {
    return apiCall.delete(['config', 'filter_engines', resource, id])
  }
}
