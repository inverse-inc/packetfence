import { set } from '@vue/composition-api'
import { utf8ToBase64 } from '@/utils/strings'

// append a PEM to a list of PEMs, unless it is already part of it
export const appendPem = (current, pem) => {
  if (!pem || !pem.trim())
    return current
  const _current = (current || '').trim()
  if (_current.includes(pem.trim()))
    return current
  return (_current) ? `${_current}\n${pem.trim()}\n` : `${pem.trim()}\n`
}

// fill a BaseFormGroupFileUpload field (path + `_upload`) with an imported PEM
export const setUploadPem = (form, namespace, pem) => {
  if (!pem)
    return
  set(form, namespace, null)
  set(form, `${namespace}_upload`, utf8ToBase64(pem))
}

export default {
  appendPem,
  setUploadPem
}
