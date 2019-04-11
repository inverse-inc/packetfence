import apiCall from '@/utils/api'
import chartsCall from '@/utils/charts'

export default {
  charts: () => {
    // http://petstore.swagger.io/?url=https://raw.githubusercontent.com/netdata/netdata/master/web/api/netdata-swagger.yaml
    // http://petstore.swagger.io/?url=https://raw.githubusercontent.com/netdata/netdata/v1.10.0/web/netdata-swagger.yaml
    return chartsCall.get(`${window.location.hostname}/api/v1/charts`).then(response => {
      return Object.values(response.data.charts)
    })
  },
  chart: (id) => {
    return chartsCall.get(`${window.location.hostname}/api/v1/chart`, { params: { chart: id } })
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
  cluster: () => {
    return apiCall.get('cluster/servers').then(response => {
      return response.data.items
    })
  }
}
