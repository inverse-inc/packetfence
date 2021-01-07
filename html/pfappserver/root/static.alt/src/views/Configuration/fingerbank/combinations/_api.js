import apiCall from '@/utils/api'

export default {
  fingerbankCombinations: params => {
    return apiCall.get(['fingerbank', 'local', 'combinations'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchCombinations: body => {
    return apiCall.post('fingerbank/local/combinations/search', body).then(response => {
      return response.data
    })
  },
  fingerbankCombination: id => {
    return apiCall.get(['fingerbank', 'local', 'combination', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateCombination: data => {
    return apiCall.post('fingerbank/local/combinations', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateCombination: data => {
    Object.keys(data).forEach(key => {
      if (/^not_/.test(key)) { // remove fields starting with 'not_'
        delete data[key]
      }
    })
    return apiCall.patch(['fingerbank', 'local', 'combination', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteCombination: id => {
    return apiCall.delete(['fingerbank', 'local', 'combination', id])
  }
}

