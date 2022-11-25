import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['config', 'connection_profiles'], { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/connection_profiles').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'connection_profile', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'connection_profile', id]).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/connection_profiles', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'connection_profile', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'connection_profile', id])
  },
  sort: data => {
    return apiCall.patch('config/connection_profiles/sort_items', data).then(response => {
      return response
    })
  },
  search: data => {
    return apiCall.post('config/connection_profiles/search', data).then(response => {
      return response.data
    })
  },

  files: params => {
    return apiCall.get(['config', 'connection_profile', params.id, 'files'], { params }).then(response => {
      return response.data
    })
  },
  file: params => {
    const method = params.quiet ? 'getQuiet' : 'get'
    return apiCall[method](['config', 'connection_profile', params.id, 'files', ...params.filename.split('/').filter(p => p)], { nocache: true }).then(response => {
      return response.data
    })
  },
  createFile: params => {
    const method = params.quiet ? 'putQuiet' : 'put'
    return apiCall[method](['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')], params.content).then(response => {
      return response.data
    })
  },
  updateFile: params => {
    const method = params.quiet ? 'patchQuiet' : 'patch'
    return apiCall[method](['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')], params.content).then(response => {
      return response.data
    })
  },
  deleteFile: params => {
    const method = params.quiet ? 'deleteQuiet' : 'delete'
    return apiCall[method](['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')])
  }
}
