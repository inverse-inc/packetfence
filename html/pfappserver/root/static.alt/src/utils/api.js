import Vue from 'vue'
import axios from 'axios'
import router from '@/router'
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
  },
  queue: new Vue({ // Vue instance required for `cache` reactivity
    data: {
      cache: [], // current pending requests
      benchmarks: {}, // stats on previous requests
      defaultBenchmark: { num: 0, time: 0, start: 0 }
    },
    methods: {
      startRequest (request) {
        this.startBenchmark(request)
        this.addCache(request)
      },
      stopRequest (request) {
        this.stopBenchmark(request)
        this.pruneCache(request)
      },
      dropRequest (request) {
        this.dropBenchmark(request)
        this.pruneCache(request)
      },
      addCache (request) {
        const { method = 'get', url = '/', params = {} } = request
        this.$set(this, 'cache', [...this.cache, { method, url, params, time: (new Date()).getTime() }]) // push request to cache
      },
      pruneCache (request) {
        const { method = 'get', url = '/', params = {} } = request
        const fIndex = this.cache.findIndex((req) => !(req.method !== method || req.url !== url || JSON.stringify(req.params) !== JSON.stringify(params)))
        if (fIndex > -1) { // pop request from cache
          this.$set(this, 'cache', [ ...this.cache.slice(0, fIndex), ...this.cache.slice(fIndex + 1, this.cache.length) ])
        }
      },
      startBenchmark (request) {
        const { method = 'get', url = '/' } = request
        const now = performance.now()
        const urlParts = url.split('/').filter((url) => { return url }) // ignore empty
        let benchmarks = this.benchmarks // initial pointer
        urlParts.forEach((urlPart, urlIndex) => {
          if (!('children' in benchmarks) && urlIndex < urlParts.length) {
            this.$set(benchmarks, 'children', {})
          } // init
          if (!(urlPart in benchmarks.children)) {
            this.$set(benchmarks.children, urlPart, {})
          }
          benchmarks = benchmarks.children[urlPart]
        })
        if (!(method in benchmarks)) {
          this.$set(benchmarks, method, JSON.parse(JSON.stringify(this.defaultBenchmark)))
        }
        this.$set(benchmarks[method], 'start', now)
      },
      stopBenchmark ({ method = 'get', url = '/', params = {} } = {}) {
        const now = performance.now()
        const urlParts = url.split('/').filter((url) => { return url }) // ignore empty
        let benchmarks = this.benchmarks // initial pointer
        urlParts.forEach(urlPart => {
          if (!(urlPart in benchmarks.children)) {
            this.$set(benchmarks.children, urlPart, {})
          }
          benchmarks = benchmarks.children[urlPart]
        })
        this.$set(benchmarks[method], 'num', benchmarks[method].num += 1)
        this.$set(benchmarks[method], 'time', benchmarks[method].time += (now - benchmarks[method].start))
        this.$set(benchmarks[method], 'start', null)
      },
      dropBenchmark ({ method = 'get', url = '/', params = {} } = {}) {
        let urlParts = url.split('/').filter((url) => { return url }) // ignore empty
        let benchmarks = this.benchmarks // initial pointer
        urlParts.forEach(urlPart => {
          if (!(urlPart in benchmarks.children)) {
            this.$set(benchmarks.children, urlPart, {})
          }
          benchmarks = benchmarks.children[urlPart]
        })
        if (method in benchmarks) {
          this.$set(benchmarks[method], 'start', null)
        }
      },
      getBenchmark (request) {
        const { method = 'get', url = '/' } = request
        let benchmarks = this.benchmarks // initial pointer
        let stats = {}
        // local recursive function
        const stat = (benchmarks, method = '', url = '') => {
          const urlParts = url.split('/').filter((url) => { return url }) // ignore empty
          urlParts.forEach(urlPart => {
            if ('children' in benchmarks && urlPart in benchmarks.children) {
              benchmarks = benchmarks.children[urlPart] // set pointer
            }
          })
          if (method in benchmarks && benchmarks[method].num > 0) {
            // method exists, return average
            return benchmarks[method]
          }
          // method not available, inspect children for same method
          if ('children' in benchmarks) {
            let num = 0
            let time = 0
            Object.keys(benchmarks.children).forEach(child => {
              stats = stat(benchmarks.children[child], method)
              if (stats && 'time' in stats && 'num' in stats) {
                num += stats.num
                time += stats.time
              }
            })
            if (num > 0 && time > 0) {
              return { time, num }
            }
          }
          // TODO search siblings, parent
          // method not available, inspect parent for same method
          urlParts.pop()
          if (urlParts.length > 0) {
            return stat(this.benchmarks, method, urlParts.join('/'))
          }
        }
        stats = stat(benchmarks, method, url)
        return (stats && 'time' in stats && 'num' in stats) ? stats : null
      },
      getEta () {
        let maxEta = (new Date()).getTime()
        this.cache.forEach((request, rIndex) => { // calculate maximum time from requests in queue
          let stats = this.getBenchmark(request)
          if (stats && 'time' in stats && 'num' in stats) {
            maxEta = Math.max(maxEta, ((new Date()).getTime() + (stats.time / stats.num)))
          }
        })
        return maxEta
      }
    }
  })
})

apiCall.interceptors.request.use((request) => {
  const { baseURL, method, url, params = {} } = request
  apiCall.queue.startRequest({ method, url: `${baseURL}${url}`, params }) // start performance benchmark
  return request
})

apiCall.interceptors.response.use((response) => {
  const { config = {} } = response
  apiCall.queue.stopRequest(config) // stop performance benchmark
  if (response.data.message && !response.data.quiet) {
    store.dispatch('notification/info', response.data.message)
  }
  store.commit('session/API_OK')
  return response
}, (error) => {
  const { config = {} } = error
  apiCall.queue.dropRequest(config) // discard performance benchmark
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
            store.dispatch('notification/danger', { icon, url: error.config.url, message: msg })
          })
        }
        // eslint-disable-next-line
        console.groupEnd()
      }
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
