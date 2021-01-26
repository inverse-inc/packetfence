import apiCall from '@/utils/api'

export default {
  fingerbankUserAgents: params => {
    return apiCall.get(['fingerbank', 'local', 'user_agents'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchUserAgents: body => {
    return apiCall.post('fingerbank/local/user_agents/search', body).then(response => {
      return response.data
    })
  },
  fingerbankUserAgent: id => {
    return apiCall.get(['fingerbank', 'local', 'user_agent', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateUserAgent: data => {
    return apiCall.post('fingerbank/local/user_agents', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateUserAgent: data => {
    return apiCall.patch(['fingerbank', 'local', 'user_agent', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteUserAgent: id => {
    return apiCall.delete(['fingerbank', 'local', 'user_agent', id])
  }
}
