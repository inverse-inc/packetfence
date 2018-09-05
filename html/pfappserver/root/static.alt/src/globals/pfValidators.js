import store from '@/store'

export const pfValidateMacAddressIsUnique = (value, component) => {
  if (!value || value.length !== 17) return true
  return store.dispatch('$_nodes/exists', value).then(results => {
    return false
  }).catch(() => {
    return true
  })
}
