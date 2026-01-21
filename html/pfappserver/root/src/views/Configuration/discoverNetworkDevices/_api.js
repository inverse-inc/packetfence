import apiCall from '@/utils/api'

export default {
  discover: data => {
    // data: { addresses: string[], credentials: Credential[], options?: Options }
    return apiCall.post('discovernetworkdevice/discover', data).then(response => {
      return response.data
    })
  },
  pollTaskStatus: ({ task_id }) => {
    return apiCall.getQuiet(`pfqueue/task/${task_id}/status/poll`).then(response => {
      return response.data
    })
  }
}
