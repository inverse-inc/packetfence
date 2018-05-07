import apiCall from '@/utils/api'

export default {
  all: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    }
    return apiCall.get('nodes', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('nodes/search', body).then(response => {
      return response.data
    })
  },
  node: mac => {
    return apiCall.get(`node/${mac}`).then(response => {
      return response.data.item
    })
  },
  ip4logOpen: mac => {
    return apiCall.get(`ip4logs/open/${mac}`).then(response => {
      return response.data.item
    })
  },
  ip4logHistory: mac => {
    return apiCall.get(`ip4logs/history/${mac}`).then(response => {
      return response.data.items
    })
  },
  ip6logOpen: mac => {
    return apiCall.get(`ip6logs/open/${mac}`).then(response => {
      return response.data.item
    })
  },
  ip6logHistory: mac => {
    return apiCall.get(`ip6logs/history/${mac}`).then(response => {
      return response.data.items
    })
  },
  locationlogs: mac => {
    const search = {
      query: { op: 'and', values: [ { field: 'mac', op: 'equals', value: mac } ] },
      limit: 100,
      cursor: '0'
    }
    return apiCall.post('locationlogs/search', search).then(response => {
      return response.data.items
    })
  },
  violations: mac => {
    const search = {
      query: { op: 'and', values: [ { field: 'mac', op: 'equals', value: mac } ] },
      limit: 100,
      cursor: '0'
    }
    return apiCall.post('violations/search', search).then(response => {
      return response.data.items
    })
  }
}
