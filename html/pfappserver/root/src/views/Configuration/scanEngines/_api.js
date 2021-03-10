import apiCall from '@/utils/api'

export default {
  scanEngines: params => {
    return apiCall.get(['config', 'scans'], { params }).then(response => {
      return response.data
    })
  },
  scanEnginesOptions: scanType => {
    return apiCall.options(['config', 'scans'], { params: { type: scanType } }).then(response => {
      return response.data
    })
  },
  scanEngine: id => {
    return apiCall.get(['config', 'scan', id]).then(response => {
      return response.data.item
    })
  },
  scanEngineOptions: id => {
    return apiCall.options(['config', 'scan', id]).then(response => {
      return response.data
    })
  },
  createScanEngine: data => {
    return apiCall.post('config/scans', data).then(response => {
      return response.data
    })
  },
  updateScanEngine: data => {
    return apiCall.patch(['config', 'scan', data.id], data).then(response => {
      return response.data
    })
  },
  deleteScanEngine: id => {
    return apiCall.delete(['config', 'scan', id])
  }
}
