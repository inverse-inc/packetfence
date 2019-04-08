import apiCall from '@/utils/api'
import chartsCall from '@/utils/charts'

export default {
  charts: () => {
    // http://petstore.swagger.io/?url=https://raw.githubusercontent.com/firehol/netdata/master/web/netdata-swagger.yaml
    return chartsCall.get(`${window.location.hostname}/api/v1/charts`).then(response => {
      return Object.values(response.data.charts)
    })
  },
  services: () => {
    return apiCall.get('services').then(response => {
      return response.data.items
    })
  },
  service: (name, action) => {
    return apiCall.get(`service/${name}/${action}`).then(response => {
      return response.data
    })
  },
  disableService: name => {
    return apiCall.post(`service/${name}/disable`).then(response => {
      const { data: { disable } } = response
      if (parseInt(disable) > 0) {
        return response.data
      } else {
        throw new Error(`Could not disable ${name}`)
      }
    })
  },
  enableService: name => {
    return apiCall.post(`service/${name}/enable`).then(response => {
      const { data: { enable } } = response
      if (parseInt(enable) > 0) {
        return response.data
      } else {
        throw new Error(`Could not enable ${name}`)
      }
    })
  },
  restartService: name => {
    return apiCall.post(`service/${name}/restart`).then(response => {
      const { data: { restart } } = response
      if (parseInt(restart) > 0) {
        return response.data
      } else {
        throw new Error(`Could not restart ${name}`)
      }
    })
  },
  startService: name => {
    return apiCall.post(`service/${name}/start`).then(response => {
      const { data: { start } } = response
      if (parseInt(start) > 0) {
        return response.data
      } else {
        throw new Error(`Could not start ${name}`)
      }
    })
  },
  stopService: name => {
    return apiCall.post(`service/${name}/stop`).then(response => {
      const { data: { stop } } = response
      if (parseInt(stop) > 0) {
        return response.data
      } else {
        throw new Error(`Could not stop ${name}`)
      }
    })
  },
  cluster: () => {
    return apiCall.get('cluster/servers').then(response => {
      return response.data.items
    })
  }
}
