/**
* "performance" store module
*/
import Vue from 'vue'

const onParPercentile = 90 // @ the estimated time set the progress bar to this %

const state = {
  now: (new Date()).getTime(), // current timestamp (ms)
  heartbeatInterval: false, // heartbeat used for interval updates on reactive model `now`
  cache: [], // all current pending requests
  benchmarks: {}, // stats on previous completed requests
  defaultBenchmark: { num: 0, time: 0, start: 0 }
}

const getters = {
  isLoading: state => {
    return state.cache.length > 0
  },
  minCacheTime: state => {
    return Math.min(...state.cache.map(cache => cache.time))
  },
  getPercentage: (state, getters) => {
    if (state.cache.length === 0) {
      return 100
    } else {
      // f(x) = 1 - e^(-k * i)
      //   k = -ln(1 - x) / i
      const eta = getters.getEta
      const now = state.now
      const min = getters.minCacheTime
      const x = (eta - min)
      const i = (now - min)
      const k = -(Math.log(1 - (onParPercentile / 100)) / x)
      const p = (1 - Math.exp(-k * i))
      return (isNaN(p)) ? 100 : Math.min(p * 100, 100)
    }
  },
  getEta: (state, getters) => {
    let maxEta = (new Date()).getTime()
    state.cache.forEach((request, rIndex) => { // calculate maximum time from requests in queue
      const { time = 0, num = 0 } = getters.getBenchmark(request)
      if (time && num) {
        maxEta = Math.max(maxEta, ((new Date()).getTime() + (time / num)))
      }
    })
    return maxEta
  },
  getBenchmark: state => request => {
    const stat = (benchmarks, method = '', url = '') => { // local recursive function
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
      // method not available, get total average of children w/ same method
      if ('children' in benchmarks) {
        let _num = 0
        let _time = 0
        Object.keys(benchmarks.children).forEach(child => {
          const { time = 0, num = 0 } = stat(benchmarks.children[child], method)
          if (time && num) {
            _num += num
            _time += time
          }
        })
        if (_time && _num) {
          return { _time, _num }
        }
      }
      // TODO search siblings, parent
      // method not available, inspect parent for same method
      urlParts.pop()
      if (urlParts.length > 0) {
        return stat(state.benchmarks, method, urlParts.join('/'))
      }
      return { time: 0, num: 0 }
    }

    const { method = 'get', url = '/' } = request
    const { time = 0, num = 0 } = stat(state.benchmarks, method, url)
    return { time, num }
  }
}

const actions = {
  startRequest: ({ commit }, request) => {
    commit('START_BENCHMARK', request)
    commit('ADD_CACHE', request)
    commit('START_HEARTBEAT')
  },
  stopRequest: ({ commit }, request) => {
    commit('STOP_BENCHMARK', request)
    commit('PRUNE_CACHE', request)
    commit('STOP_HEARTBEAT')
  },
  dropRequest: ({ commit }, request) => {
    commit('DROP_BENCHMARK', request)
    commit('PRUNE_CACHE', request)
    commit('STOP_HEARTBEAT')
  }
}

const mutations = {
  START_HEARTBEAT: (state) => {
    if (!state.heartbeatInterval && state.cache.length > 0) {
      state.heartbeatInterval = setInterval(() => {
        state.now = (new Date()).getTime()
      }, 100)
    }
    state.now = (new Date()).getTime()
  },
  STOP_HEARTBEAT: (state) => {
    if (state.heartbeatInterval && state.cache.length === 0) {
      clearInterval(state.heartbeatInterval)
      state.heartbeatInterval = false
    }
  },
  ADD_CACHE: (state, request) => {
    const { method = 'get', url = '/', params = {} } = request
    const cache = [...state.cache, { method, url, params, time: (new Date()).getTime() }]
    Vue.set(state, 'cache', cache)
  },
  PRUNE_CACHE: (state, request) => {
    const { method = 'get', url = '/', params = {} } = request
    const fIndex = state.cache.findIndex((req) => !(req.method !== method || req.url !== url || JSON.stringify(req.params) !== JSON.stringify(params)))
    if (fIndex > -1) {
      const cache = [ ...state.cache.slice(0, fIndex), ...state.cache.slice(fIndex + 1, state.cache.length) ]
      Vue.set(state, 'cache', cache)
    }
  },
  START_BENCHMARK: (state, request) => {
    const { method = 'get', url = '/' } = request
    const now = performance.now()
    const urlParts = url.split('/').filter((url) => { return url }) // ignore empty
    let benchmarks = state.benchmarks // initial pointer
    urlParts.forEach((urlPart, urlIndex) => {
      if (!('children' in benchmarks) && urlIndex < urlParts.length) {
        Vue.set(benchmarks, 'children', {})
      } // init
      if (!(urlPart in benchmarks.children)) {
        Vue.set(benchmarks.children, urlPart, {})
      }
      benchmarks = benchmarks.children[urlPart]
    })
    if (!(method in benchmarks)) {
      Vue.set(benchmarks, method, state.defaultBenchmark)
    }
    Vue.set(benchmarks[method], 'start', now)
  },
  STOP_BENCHMARK: (state, request) => {
    const { method = 'get', url = '/' } = request
    const now = performance.now()
    const urlParts = url.split('/').filter((url) => { return url }) // ignore empty
    let benchmarks = state.benchmarks // initial pointer
    urlParts.forEach(urlPart => {
      if (!(urlPart in benchmarks.children)) {
        Vue.set(benchmarks.children, urlPart, {})
      }
      benchmarks = benchmarks.children[urlPart]
    })
    Vue.set(benchmarks[method], 'num', benchmarks[method].num += 1)
    Vue.set(benchmarks[method], 'time', benchmarks[method].time += (now - benchmarks[method].start))
    Vue.set(benchmarks[method], 'start', null)
  },
  DROP_BENCHMARK: (state, request) => {
    const { method = 'get', url = '/' } = request
    const urlParts = url.split('/').filter((url) => { return url }) // ignore empty
    let benchmarks = state.benchmarks // initial pointer
    urlParts.forEach(urlPart => {
      if (!(urlPart in benchmarks.children)) {
        Vue.set(benchmarks.children, urlPart, {})
      }
      benchmarks = benchmarks.children[urlPart]
    })
    if (method in benchmarks) {
      Vue.set(benchmarks[method], 'start', null)
    }
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
