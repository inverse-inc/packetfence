import apiCall from '@/utils/api'

export default {
  hostname: () => apiCall.get(['config', 'system', 'hostname']).then(response => response.data.item)
}
