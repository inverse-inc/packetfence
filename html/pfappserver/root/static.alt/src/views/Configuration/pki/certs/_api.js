import apiCall from '@/utils/api'

export default {
  pkiCerts: () => {
    return apiCall.get('pki/certs').then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  pkiCert: id => {
    return apiCall.get(['pki', 'cert', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  },
  createPkiCert: data => {
    return apiCall.post('pki/certs', data).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return item
      }
    })
  },
  downloadPkiCert: data => {
    const { id, password } = data
    return apiCall.getArrayBuffer(['pki', 'cert', id, 'download', password]).then(response => {
      const { data, data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        return data
      }
    })
  },
  emailPkiCert: id => {
    return apiCall.get(['pki', 'cert', id, 'email']).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { password } = {} } = response
        return { password }
      }
    })
  },
  revokePkiCert: data => {
    return apiCall.delete(['pki', 'cert', data.id, data.reason]).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        return true
      }
    })
  }
}
