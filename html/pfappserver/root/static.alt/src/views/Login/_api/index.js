import apiCall from '@/utils/api'

export default {
  login: user => {
    return apiCall.post('login', user).then(response => {
      apiCall.defaults.headers.common['Authorization'] = `Bearer ${response.data.token}`
      return response
    })
  }
}
