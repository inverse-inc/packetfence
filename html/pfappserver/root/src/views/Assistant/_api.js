import apiCall from '@/utils/api'

// The assistant (lib/pfchatbot) is reached through the admin API at
// /api/v1/pfchatbot, so every call carries the admin session and is
// authorized by the AAA layer: CHATBOT_READ for the service, CHATBOT_WRITE
// for anything under /write/. Its errors are {"error": "..."}; callers
// handle them inline, hence the quiet variants.
const unwrap = response => response.data

export default {
  config: () => apiCall.getQuiet('pfchatbot/config').then(unwrap),
  settings: () => apiCall.getQuiet('pfchatbot/settings').then(unwrap),
  models: () => apiCall.getQuiet('pfchatbot/models').then(unwrap),
  testProvider: data => apiCall.postQuiet('pfchatbot/write/settings/test', data).then(unwrap),

  threads: () => apiCall.getQuiet('pfchatbot/threads').then(unwrap),
  searchThreads: q => apiCall.getQuiet('pfchatbot/threads/search', { params: { q } }).then(unwrap),
  thread: id => apiCall.getQuiet(['pfchatbot', 'threads', id]).then(unwrap),
  deleteThread: id => apiCall.deleteQuiet(['pfchatbot', 'threads', id]).then(unwrap),

  chat: (data, config) => apiCall.postQuiet('pfchatbot/chat', data, config).then(unwrap),
  cancel: run_id => apiCall.postQuiet('pfchatbot/cancel', { run_id }).then(unwrap),
  feedback: data => apiCall.postQuiet('pfchatbot/feedback', data).then(unwrap),
  confirmWrite: data => apiCall.postQuiet('pfchatbot/write/confirm_write', data).then(unwrap),

  usage: () => apiCall.getQuiet('pfchatbot/usage').then(unwrap),

  roles: () => apiCall.getQuiet('pfchatbot/roles').then(unwrap),
  node: mac => apiCall.getQuiet(['pfchatbot', 'node', mac]).then(unwrap),
  nodeStatus: (mac, status) => apiCall.postQuiet(`pfchatbot/write/node/${encodeURIComponent(mac)}/status`, { status }).then(unwrap),
  nodeRole: (mac, category_id) => apiCall.postQuiet(`pfchatbot/write/node/${encodeURIComponent(mac)}/role`, { category_id }).then(unwrap),
  nodeReevaluate: mac => apiCall.postQuiet(`pfchatbot/write/node/${encodeURIComponent(mac)}/reevaluate`, {}).then(unwrap),

  files: params => apiCall.getQuiet('pfchatbot/files', { params }).then(unwrap),
  uploadFile: data => apiCall.postQuiet('pfchatbot/files/upload', data).then(unwrap),
  downloadFile: id => apiCall.request({ method: 'get', url: `pfchatbot/files/${id}/download`, responseType: 'blob' }),
  deleteFile: id => apiCall.deleteQuiet(['pfchatbot', 'files', id]).then(unwrap),

  testTools: () => apiCall.getQuiet('pfchatbot/testtools').then(unwrap),
  testToolsHealth: () => apiCall.getQuiet('pfchatbot/testtools/health').then(unwrap),
  testToolsRun: data => apiCall.postQuiet('pfchatbot/write/testtools/run', data).then(unwrap),
  testToolsCapture: data => apiCall.postQuiet('pfchatbot/write/testtools/capture', data).then(unwrap)
}
