import { default as apiCall, pfappserverCall } from '@/utils/api'
import qs from 'qs'

export default {
  login: user => {
    return apiCall.post('login', user).then(response => {
      apiCall.defaults.headers.common['Authorization'] = `Bearer ${response.data.token}`
      // Perform login through pfappserver to obtain an HTTP cookie and therefore gain access to the previous Web admin.
      pfappserverCall.post('login', qs.stringify(user), {'Content-Type': 'application/x-www-form-urlencoded'})
      return response
    })
  }
}
