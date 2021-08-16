import apiCall from '@/utils/api'

export default {
  certificate: id => {
    return apiCall.getQuiet(['config', 'certificate', id]).then(response => {
      return response.data
    })
  },
  certificateInfo: id => {
    return apiCall.get(['config', 'certificate', id, 'info']).then(response => {
      return response.data
    })
  },
  createCertificate: data => {
    return apiCall.put(['config', 'certificate', data.id], data, { params: { check_chain: data.check_chain } }).then(response => {
      return response.data
    })
  },
  createLetsEncryptCertificate: data => {
    return apiCall.put(['config', 'certificate', data.id, 'lets_encrypt'], data).then(response => {
      return response.data
    })
  },
  generateCertificateSigningRequest: data => {
    return apiCall.post(['config', 'certificate', data.id, 'generate_csr'], data).then(response => {
      return response.data
    })
  },
  testLetsEncrypt: domain => {
    return apiCall.get('config/certificates/lets_encrypt/test', { params: { domain } }).then(response => {
      return response.data
    })
  }
}
