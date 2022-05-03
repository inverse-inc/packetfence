import apiCall from '@/utils/api'
import {
  mac,
  proto,
  port,
  host,
  device_class
} from './mock'

export default {

  search: params => {
    const { limit, selectedDevices = [], selectedProtocols = [], selectedHosts = [], selectedCategories = [] } = params
    let timestamp = 1650564944000
    const items = new Array(limit).fill(null).map((_, i) => {
      timestamp += Math.floor(Math.random() * 60 * 1E3)
      return {
        i,
        timestamp,
        mac: mac(selectedDevices),
        proto: proto(selectedProtocols.map(p => p.split('/')[0])),
        port: port(selectedProtocols.map(p => +p.split('/')[1])),
        host: host(selectedHosts),
        device_class: device_class(selectedCategories)
      }
    })
    return new Promise(resolve => resolve({ items }))

/*
    return apiCall.post('config/roles/search', data).then(response => {
      return response.data
    })
*/
  }
}
