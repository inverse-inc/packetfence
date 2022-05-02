import apiCall from '@/utils/api'
import {
  mac,
  proto,
  port,
  host,
  device_class
} from './mock'

export default {

  search: data => {

    console.log({ data })

    let timestamp = 1650564944000

    const items = new Array(data.limit).fill(null).map((_, i) => {
      timestamp += Math.floor(Math.random() * 60 * 1E3)

      return {
        i,
        timestamp,
        mac: mac(),
        proto: proto(),
        port: port(),
        host: host(),
        device_class: device_class()
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
