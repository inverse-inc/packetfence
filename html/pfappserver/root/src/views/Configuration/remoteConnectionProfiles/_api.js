import apiCall from '@/utils/api'

export default {
  remoteConnectionProfiles: params => {
    return apiCall.get(['config', 'remote_connection_profiles'], { params }).then(response => {
      return response.data
    })
  },
  remoteConnectionProfilesOptions: () => {
    return apiCall.options('config/remote_connection_profiles').then(response => {
      return response.data
    })
  },
  remoteConnectionProfile: id => {
    return apiCall.get(['config', 'remote_connection_profile', id]).then(response => {
      return response.data.item
    })
  },
  remoteConnectionProfileOptions: id => {
    return apiCall.options(['config', 'remote_connection_profile', id]).then(response => {
      return response.data
    })
  },
  createRemoteConnectionProfile: data => {
    return apiCall.post('config/remote_connection_profiles', data).then(response => {
      return response.data
    })
  },
  updateRemoteConnectionProfile: data => {
    return apiCall.patch(['config', 'remote_connection_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRemoteConnectionProfile: id => {
    return apiCall.delete(['config', 'remote_connection_profile', id])
  },
  sortRemoteConnectionProfiles: data => {
    return apiCall.patch('config/remote_connection_profiles/sort_items', data).then(response => {
      return response
    })
  }
}
