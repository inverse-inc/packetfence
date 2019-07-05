import axios from 'axios'
import store from '@/store'

const apiCall = axios.create({
  baseURL: '/api/v1/'
})

Object.assign(apiCall, {
  deleteQuiet (url) {
    return this.request({
      method: 'delete',
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
  patchQuiet (url, data) {
    return this.request({
      method: 'patch',
      url,
      data,
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
  postQuiet (url, data) {
    return this.request({
      method: 'post',
      url,
      data,
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
  putQuiet (url, data) {
    return this.request({
      method: 'put',
      url,
      data,
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

apiCall.interceptors.request.use((request) => {
  const { baseURL, method, url, params = {} } = request
  const apiServer = localStorage.getItem('X-PacketFence-Server') || null
  if (apiServer) {
    request.headers['X-PacketFence-Server'] = apiServer
  }
  store.dispatch('performance/startRequest', { method, url: `${baseURL}${url}`, params }) // start performance benchmark
  return request
})

apiCall.interceptors.response.use((response) => {
  /* Intercept successful API call */
  const { config = {}, data = {} } = response
  if (data.message && !data.quiet) {
    store.dispatch('notification/info', { message: data.message, url: config.url })
  }
  store.commit('session/API_OK')
  store.commit('session/FORM_OK')
  return response
}, (error) => {
  /* Intercept failed API call */
  const { config = {} } = error
  let icon = 'exclamation-triangle'
  if (error.response) {
    if (error.response.status === 401 || // unauthorized
      (error.response.status === 404 && /token_info/.test(config.url))) {
      // Token has expired
      if (!error.response.data.quiet) {
        store.commit('session/EXPIRED')
        // Reply request once the session is restored
        return store.dispatch('session/resolveLogin').then(response => {
          const { method, url, params, data } = config
          return apiCall.request({ method, baseURL: '', url, params, data, headers: { 'X-Replay': 'true' } })
        })
      }
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
      if (!error.response.data.quiet) {
        // eslint-disable-next-line
        console.group('API error')
        // eslint-disable-next-line
        console.warn(error.response.data)
        if (error.response.data.errors) {
          error.response.data.errors.forEach((err, errIndex) => {
            let msg = `${err['field']}: ${err['message']}`
            // eslint-disable-next-line
            console.warn(msg)
            store.dispatch('notification/danger', { icon, url: config.url, message: msg })
          })
        }
        // eslint-disable-next-line
        console.groupEnd()
      }
      if (['patch', 'post', 'put', 'delete'].includes(config.method) && error.response.data.errors) {
        let formErrors = {}
        error.response.data.errors.forEach((err, errIndex) => {
          formErrors[err['field']] = err['message']
        })
        if (Object.keys(formErrors).length > 0) {
          store.commit('session/FORM_ERROR', formErrors)
        }
      }
      if (typeof error.response.data === 'string') {
        store.dispatch('notification/danger', { icon, url: config.url, message: error.message })
      } else if (error.response.data.message && !error.response.data.quiet) {
        store.dispatch('notification/danger', { icon, url: config.url, message: error.response.data.message })
      }
    }
  } else if (error.request) {
    store.commit('session/API_ERROR')
    store.dispatch('notification/danger', { url: config.url, message: 'API server seems down' })
  }
  return Promise.reject(error)
})

export const pfappserverCall = axios.create({
  baseURL: '/admin/'
})

export default apiCall
