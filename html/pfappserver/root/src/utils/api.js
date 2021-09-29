import axios from 'axios'
import store from '@/store'

export const baseURL = (process.env.VUE_APP_API_BASEURL)
  ? process.env.VUE_APP_API_BASEURL
  : '/api/v1/'

const apiCall = axios.create({
  baseURL
})

/**
 * Remap some aliases to accept an array as the URL.
 * When the URL is an array, each segment will be URL-encoded before building the final URL.
 */

function _encodeURL (url) {
  if (Array.isArray(url)) {
    return url.map(segment => encodeURIComponent(segment.toString())).join('/')
  }
  return url
}

const methodsWithoutData = ['get', 'head', 'options']
methodsWithoutData.forEach((method) => {
  apiCall[method] = (url, config = {}) => {
    return apiCall.request({ ...config, method, url: _encodeURL(url) })
  }
})

const methodsWithData = ['post', 'put', 'patch', 'delete']
methodsWithData.forEach((method) => {
  apiCall[method] = (url, data, config = {}) => {
    return apiCall.request({ ...config, method, url: _encodeURL(url), data })
  }
})

/**
 * Add new "quiet" methods that won't trigger any message in the notification center.
 */

Object.assign(apiCall, {
  deleteQuiet (url) {
    return this.request({
      method: 'delete',
      url: _encodeURL(url),
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
  getArrayBuffer (url) {
    return this.request({
      responseType: 'arraybuffer',
      method: 'get',
      url: _encodeURL(url)
    })
  },
  getQuiet (url) {
    return this.request({
      method: 'get',
      url: _encodeURL(url),
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
  optionsQuiet (url) {
    return this.request({
      method: 'options',
      url: _encodeURL(url),
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
      url: _encodeURL(url),
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
      url: _encodeURL(url),
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
      url: _encodeURL(url),
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

/**
 * Intercept requests
 */

 apiCall.interceptors.request.use((request) => {
  const apiServer = localStorage.getItem('X-PacketFence-Server') || null
  if (apiServer) {
    request.headers['X-PacketFence-Server'] = apiServer
  }
  if (!('X-PacketFence-Tenant-Id' in request.headers)) {
    const apiTenant = localStorage.getItem('X-PacketFence-Tenant-Id')
    if (apiTenant) {
      request.headers['X-PacketFence-Tenant-Id'] = apiTenant
    }
    else {
      const { state: { session: { tenant } = {} } = {} } = store
      if (tenant) {
        const { id } = tenant
        request.headers['X-PacketFence-Tenant-Id'] = id
      }
    }
  }
  return request
})

/**
 * Intercept responses to
 *
 * - detect messages in payload and display them in the notification center;
 * - detect if the token has expired;
 * - detect errors assigned to specific form fields.
 */

apiCall.interceptors.response.use((response) => {
  /* Intercept successful API call */
  const { config: { url } = {}, data: { message, warnings, quiet } = {} } = response
  if (message && !quiet) {
    store.dispatch('notification/info', { message, url })
  }
  if (warnings && !quiet) {
    warnings.forEach(warning => {
      const { message } = warning
      store.dispatch('notification/warning', { message, url })
    })
  }
  store.commit('session/API_OK')
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
        return store.dispatch('session/resolveLogin').then(() => {
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
          error.response.data.errors.forEach(error => {
            let message = `${error['field']}: ${error['message']}`
            // eslint-disable-next-line
            console.warn(message)
            store.dispatch('notification/danger', { icon, url: decodeURIComponent(config.url), message })
          })
        }
        // eslint-disable-next-line
        console.groupEnd()
      }
      if (['patch', 'post', 'put', 'delete'].includes(config.method) && error.response.data.errors) {
        let apiErrors = {}
        error.response.data.errors.forEach((err) => {
          apiErrors[err['field']] = err['message']
        })
        if (Object.keys(apiErrors).length > 0) {
          store.commit('session/API_ERRORS', apiErrors)
        }
      }
      if (typeof error.response.data === 'string') {
        store.dispatch('notification/danger', { icon, url: decodeURIComponent(config.url), message: error.message })
      } else if (error.response.data.message && !error.response.data.quiet) {
        store.dispatch('notification/danger', { icon, url: decodeURIComponent(config.url), message: error.response.data.message })
      }
    }
  } else if (error.request) {
    const { transformResponse: [firstTransform] = [] } = error.config
    let quiet = false
    if (firstTransform) {
      quiet = firstTransform().quiet
    }
    if (!quiet) {
      store.commit('session/API_ERROR')
      store.dispatch('notification/danger', { url: decodeURIComponent(config.url), message: 'API server seems down' })
    }
  }
  return Promise.reject(error)
})

/**
 * Axios instance to access documentation guides
 */
export const documentationCall = axios.create({
  baseURL: '/static/doc/'
})

export default apiCall
