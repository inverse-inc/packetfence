/**
 * Custom Vuelidate Validators
 *
 * See Builtin Validators: https://monterail.github.io/vuelidate/#sub-builtin-validators
 *
**/
import store from '@/store'
import { parse, format } from 'date-fns'

const _common = require('vuelidate/lib/validators/common')

export const categoryIdNumberExists = (value, component) => {
  if (!value || !/\d+/.test(value)) return true
  if (store.state.config.roles.filter(role => role.category_id === value).length === 0) return false
  return true
}

export const categoryIdStringExists = (value, component) => {
  if (!value || /\d+/.test(value)) return true
  if (store.state.config.roles.filter(role => role.name.toLowerCase() === value.toLowerCase()).length === 0) return false
  return true
}

export const inArray = (array) => {
  return (0, _common.withParams)({
    type: 'inArray',
    array: array
  }, function (value) {
    return !(0, _common.req)(value) || array.includes(value)
  })
}

export const isDate = (value) => (!value) || value === '0000-00-00' || format(parse(value), 'YYYY-MM-DD') === value

export const isDateTime = (value) => (!value) || value === '0000-00-00 00:00:00' || format(parse(value), 'YYYY-MM-DD HH:mm:ss') === value

export const macAddressIsUnique = (value, component) => {
  if (!value || value.length !== 17) return true
  return store.dispatch('$_nodes/exists', value).then(results => {
    return false
  }).catch(() => {
    return true
  })
}

export const userExists = (value, component) => {
  if (!value) return true
  return store.dispatch('$_users/exists', value).then(results => {
    return true
  }).catch(() => {
    return false
  })
}
