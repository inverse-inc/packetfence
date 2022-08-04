import apiCall from '@/utils/api'

export default {
  search: body => {
    return apiCall.post('nodes/network_graph', body).then(response => {
      return response.data
    })
  }
}