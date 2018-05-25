import axios from 'axios'
import router from '@/router'
import store from '@/store'

const apiCall = axios.create({
  baseURL: 'https://' + window.location.hostname + ':9999/api/v1/'
})

apiCall.interceptors.response.use((response) => response,
  (error) => {
    if (error.response) {
      if (error.response.status === 401 || // unauthorized
          (error.response.status === 404 && /token_info/.test(error.config.url))) {
        router.push('/expire')
      }
      if (error.response.data) {
        console.group('API error')
        console.log(error.response.data.message)
        if (error.response.data.errors) {
          error.response.data.errors.forEach(err => {
            Object.keys(err).forEach(attr => {
              console.log(`${attr}: ${err[attr]}`)
            })
          })
        }
        console.groupEnd()
      }
    } else if (error.request) {
      store.commit('session/API_ERROR')
    }
    return Promise.reject(error)
  }
)

export default apiCall
