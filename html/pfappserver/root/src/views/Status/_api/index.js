import apiCall from '@/utils/api'
import chartsCall from '@/utils/charts'

export default {
  charts: (ip) => {
    // http://petstore.swagger.io/?url=https://raw.githubusercontent.com/netdata/netdata/master/web/api/netdata-swagger.yaml
    // http://petstore.swagger.io/?url=https://raw.githubusercontent.com/netdata/netdata/v1.10.0/web/netdata-swagger.yaml
    return chartsCall.get(`${ip}/api/v1/charts`).then(response => {
      return Object.values(response.data.charts)
    })
  },
  chart: (id) => {
    return chartsCall.get('127.0.0.1/api/v1/chart', { params: { chart: id } })
  },
  alarms: (ip) => {
    return chartsCall.get(`${ip}/api/v1/alarms`).then(response => {
      return response.data
    })
  }
}
