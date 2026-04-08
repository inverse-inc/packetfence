import apiCall from '@/utils/api'
import store from '@/store'

const isSaas = () => {
  const { state: { system: { summary: { saas } = {} } = {} } = {} } = store
  return !!saas
}

const prefix = () => {
  return isSaas() ? 'eslogs' : 'logs'
}

export default {
  create: body => {
    if (isSaas()) {
      return apiCall.postQuiet(`eslogs/tail`, body).then(response => {
        return response.data
      })
    }
    return apiCall.post(`logs/tail`, body).then(response => {
      return response.data
    })
  },
  delete: id => {
    if (isSaas()) {
      return Promise.resolve({})
    }
    return apiCall.delete([prefix(), 'tail', id]).then(response => {
      return response.data
    })
  },
  item: (id, pollBody) => {
    if (isSaas() && pollBody) {
      return apiCall.postQuiet(`eslogs/tail`, pollBody).then(response => {
        return response.data
      })
    }
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
    if (isSaas()) {
      return Promise.resolve({})
    }
    return apiCall.postQuiet([prefix(), 'tail', id, 'touch']).then(response => {
      return response.data
    })
  }
}
