import axios from 'axios'
import router from '@/router'
import store from '@/store'

const apiCall = axios.create({
  baseURL: '/api/v1/'
})

Object.assign(apiCall, {
  getQuiet (url) {
    return this.request({
      method: 'get',
      url,
      transformResponse: [data => {
        let jsonData
        try {
          jsonData = JSON.parse(data)
        } catch (e) {
          jsonData = {}
        }
        return Object.assign({ quiet: true }, jsonData)
      }]
    })
  },
  postQuiet (url, body) {
    return this.request({
      method: 'post',
      url,
      body,
      transformResponse: [data => {
        let jsonData
        try {
          jsonData = JSON.parse(data)
        } catch (e) {
          jsonData = {}
        }
        return Object.assign({ quiet: true }, jsonData)
      }]
    })
  }
})

apiCall.interceptors.response.use((response) => {
  if (response.data.message) {
    store.dispatch('notification/info', response.data.message)
  }
  store.commit('session/API_OK')
  return response
}, (error) => {
  let icon = 'exclamation-triangle'
  if (error.response) {
    if (error.response.status === 401 || // unauthorized
      (error.response.status === 404 && /token_info/.test(error.config.url))) {
      let currentPath = router.currentRoute.fullPath
      if (currentPath === '/') {
        currentPath = document.location.hash.substring(1)
      }
      router.push({ name: 'login', params: { expire: true, previousPath: currentPath } })
    } else if (error.response.data) {
      switch (error.response.status) {
        case 401:
          icon = 'ban'
          break
        case 404:
          icon = 'unlink'
          break
        case 503:
          store.commit('session/API_ERROR')
          break
      }
      // eslint-disable-next-line
      console.group('API error')
      // eslint-disable-next-line
      console.warn(error.response.data)
      if (error.response.data.errors) {
        error.response.data.errors.forEach(err => {
          Object.keys(err).forEach(attr => {
            // eslint-disable-next-line
            console.warn(`${attr}: ${err[attr]}`)
          })
        })
      }
      // eslint-disable-next-line
      console.groupEnd()
      if (typeof error.response.data === 'string') {
        store.dispatch('notification/danger', { icon, url: error.config.url, message: error.message })
      } else if (error.response.data.message && !error.response.data.quiet) {
        store.dispatch('notification/danger', { icon, url: error.config.url, message: error.response.data.message })
      }
    }
  } else if (error.request) {
    store.commit('session/API_ERROR')
    store.dispatch('notification/danger', { url: error.config.url, message: 'API server seems down' })
  }
  return Promise.reject(error)
})

export const pfappserverCall = axios.create({
  baseURL: '/admin/'
})

export default apiCall
