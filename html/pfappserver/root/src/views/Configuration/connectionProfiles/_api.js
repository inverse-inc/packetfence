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
    const get = params.quiet ? 'getQuiet' : 'get'
    return apiCall[get](['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')]).then(response => {
      return response.data
    })
  },
  createFile: params => {
    return apiCall.put(['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')], params.content).then(response => {
      return response.data
    })
  },
  updateFile: params => {
    return apiCall.patch(['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')], params.content).then(response => {
      return response.data
    })
  },
  deleteFile: params => {
    return apiCall.delete(['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')])
  }
}
