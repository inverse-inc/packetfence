import apiCall from '@/utils/api'

export default {
  vips: () => {
    return apiCall.get('cluster/vips').then(response => response.data)
  }
}
