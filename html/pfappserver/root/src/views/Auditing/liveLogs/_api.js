import apiCall from '@/utils/api'
import store from '@/store'

const prefix = () => store.getters['system/isSaas'] ? 'eslogs' : 'logs'

export default {
  create: body => {
    return apiCall.post(`${prefix()}/tail`, body).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete([prefix(), 'tail', id]).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.getQuiet(`${prefix()}/tail/${id}`, { performance: false }).then(response => {
      return response.data
    })
  },
  options: () => {
    return apiCall.options(`${prefix()}/tail`).then(response => {
      return response.data
    })
  },
  touch: id => {
    return apiCall.postQuiet([prefix(), 'tail', id, 'touch']).then(response => {
      return response.data
    })
  }
}
