/**
 * Custom Vuelidate Validators
 *
 * See Builtin Validators: https://monterail.github.io/vuelidate/#sub-builtin-validators
 *
 * Vuelidate version 0.7.3 functions that do not handle Promises:
 *
 *  - and
 *  - or
 *  - not
 *
**/
import store from '@/store'
import { parse, format, isValid, compareAsc } from 'date-fns'

const _common = require('vuelidate/lib/validators/common')

/**
 * Default replacements - Fix Promises
**/

// Default vuelidate |and| replacement, handles Promises
export const and = (...validators) => {
  return _common.withParams({ type: 'and' }, function (...args) {
    return (
      validators.filter(v => v).length > 0 &&
      Promise.all(validators.filter(v => v).map(fn => fn.apply(this, args))).then(values => {
        return values.reduce((valid, value) => {
          return valid && value
        }, true)
      })
    )
  })
}

// Default vuelidate |or| replacement, handles Promises
export const or = (...validators) => {
  return _common.withParams({ type: 'or' }, function (...args) {
    return (
      validators.filter(v => v).length > 0 &&
      Promise.all(validators.filter(v => v).map(fn => fn.apply(this, args))).then(values => {
        return values.reduce((valid, value) => {
          return valid || value
        }, false)
      })
    )
  })
}

// Default vuelidate |not| replacement, handles Promises
export const not = (validator) => {
  return _common.withParams({ type: 'not' }, function (value, vm) {
    let newValue = validator.call(this, value, vm)
    if (Promise.resolve(newValue) === newValue) { // is it a Promise?
      // wait for promise to resolve before inverting it
      return newValue.then((value) => !value)
    }
    return !newValue
  })
}

// Default vuelidate |alphaNum| replacement, accepts underscore
export const alphaNum = () => {
  return _common.regex('alphaNum', /^[a-zA-Z0-9_]*$/)
}

/**
 *
 * Custom functions
 *
**/
export const conditional = (conditional) => {
  return (0, _common.withParams)({
    type: 'conditional',
    conditional: conditional
  }, function (value, vm) {
    return (conditional && conditional.constructor === Function)
      ? (value === undefined)
        ? conditional(undefined, vm)
        : conditional(JSON.parse(JSON.stringify(value)), vm) // dereference value
      : conditional
  })
}

export const inArray = (array) => {
  return (0, _common.withParams)({
    type: 'inArray',
    array: array
  }, function (value) {
    return !(0, _common.req)(value) || array.includes(value)
  })
}

export const ipAddress = (value) => {
  if (!value) return true
  return /^(([0-9]{1,3}.){3,3}[0-9]{1,3})$/i.test(value)
}

export const ipv6Address = (value) => {
  if (!value) return true
  return /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/i.test(value)
}

export const isCIDR = (value) => {
  if (!value) return true
  const [ipv4, network, ...extra] = value.split('/')
  return (
    extra.length === 0 &&
    ~~network > 0 && ~~network < 31 &&
    ipv4 && ipAddress(ipv4)
  )
}

export const isDateFormat = (dateFormat, allowZero = true) => {
  return (0, _common.withParams)({
    type: 'isDateFormat',
    dateFormat: dateFormat,
    allowZero: allowZero
  }, function (value) {
    return !(0, _common.req)(value) || format(parse(value), dateFormat) === value || (dateFormat.replace(/[a-z]/gi, '0') === value && allowZero)
  })
}

export const isFingerbankDevice = (value) => {
  if (!value) return true
  return /^([0-9A-F]{3})$/i.test(value)
}

export const isFingerprint = (value) => {
  if (!value) return true
  return /^(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?),)?)+(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(value)
}

export const isFQDN = (value) => {
  if (!value) return true
  const parts = value.split('.')
  const tld = parts.pop()
  if (!parts.length || !/^([a-z\u00a1-\uffff]{2,}|xn[a-z0-9-]{2,})$/i.test(tld)) {
    return false
  }
  for (let i = 0; i < parts.length; i++) {
    let part = parts[i]
    if (part.indexOf('__') >= 0) {
      return false
    }
    if (!/^[a-z\u00a1-\uffff0-9-_]+$/i.test(part)) {
      return false
    }
    if (/[\uff01-\uff5e]/.test(part)) {
      // disallow full-width chars
      return false
    }
    if (part[0] === '-' || part[part.length - 1] === '-') {
      return false
    }
  }
  return true
}

export const isHex = (value) => {
  if (!value) return true
  return /^[0-9a-f]+$/i.test(value)
}

export const isMacAddress = (value) => {
  if (!value) return true
  return value.toLowerCase().replace(/[^0-9a-f]/g, '').length === 12
}

export const isOUI = (separator = ':') => {
  return (0, _common.withParams)({
    type: 'isOUI',
    separator: separator
  }, function (value) {
    if (!value) return true
    if (separator === '') {
      return /^([0-9A-F]{6})$/i.test(value)
    } else {
      value.split(separator).forEach(segment => {
        if (!/^([0-9A-F]{2})$/i.test(segment)) return false
      })
      return true
    }
  })
}

export const isPattern = (pattern) => {
  return (0, _common.withParams)({
    type: 'isPattern',
    pattern: pattern
  }, function (value) {
    const re = new RegExp(`^${pattern}$`)
    return !(0, _common.req)(value) || re.test(value)
  })
}

export const isPort = (value) => {
  if (!value) return true
  return ~~value === parseFloat(value) && ~~value >= 1 && ~~value <= 65535
}

export const isPrice = (value) => {
  if (!value) return true
  return /^-?\d+\.\d{2}$/.test(value)
}

export const isVLAN = (value) => {
  if (!value) return true
  return ~~value === parseFloat(value) && ~~value >= 1 && ~~value <= 4096
}

export const emailsCsv = (value) => {
  if (!value) return true
  const emailRegex = /(^$|^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$)/
  const emails = value.split(',')
  for (var i = 0; i < emails.length; i++) {
    if (!emailRegex.test(emails[i].trim())) return false
  }
  return true
}

export const compareDate = (comparison, date = new Date(), dateFormat = 'YYYY-MM-DD HH:mm:ss', allowZero = true) => {
  return (0, _common.withParams)({
    type: 'compareDate',
    comparison: comparison,
    date: date,
    dateFormat: dateFormat,
    allowZero: allowZero
  }, function (value) {
    // ignore empty or zero'd (0000-00-00...)
    if (!value || (value === dateFormat.replace(/[a-z]/gi, '0') && allowZero)) return true
    // round date/value using dateFormat
    date = parse(format((date instanceof Date && isValid(date) ? date : parse(date)), dateFormat))
    value = parse(format((value instanceof Date && isValid(value) ? value : parse(value)), dateFormat))
    // compare
    const cmp = compareAsc(value, date)
    switch (comparison.toLowerCase()) {
      case '>': case 'gt': return (cmp > 0)
      case '>=': case 'gte': return (cmp >= 0)
      case '<': case 'lt': return (cmp < 0)
      case '<=': case 'lte': return (cmp <= 0)
      case '===': case 'eq': return (cmp === 0)
      case '!==': case 'ne': return (cmp !== 0)
      default: return false
    }
  })
}

export const isValidUnregDateByAclUser = (dateFormat = 'YYYY-MM-DD', allowZero = true) => {
  return (0, _common.withParams)({
    type: 'isValidUnregDateByAclUser',
    dateFormat: dateFormat,
    allowZero: allowZero
  }, function (value) {
    // ignore empty or zero'd (0000-00-00...)
    if (!value || (value === dateFormat.replace(/[a-z]/gi, '0') && allowZero)) return true
    value = parse(format((value instanceof Date && isValid(value) ? value : parse(value)), dateFormat))
    return store.dispatch('session/getAllowedUserUnregDate').then(response => {
      const { 0: unregDate } = response
      if (unregDate) {
        return compareAsc(parse(unregDate), value) >= 0
      }
      return true
    }).catch(() => {
      return true
    })
  })
}

export const isFilenameWithExtension = (extensions = ['html']) => {
  return (0, _common.withParams)({
    type: 'isFilenameWithExtension',
    extensions: extensions
  }, function (value) {
    const re = RegExp('^[a-zA-Z0-9_]+[a-zA-Z0-9_\\-\\.]*\\.(' + extensions.join('|') + ')$')
    return re.test(value)
  })
}

export const hasInterfaces = () => {
  return store.dispatch('config/getInterfaces').then(response => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasPortalModules = () => {
  return store.dispatch('config/getPortalModules').then(response => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasSwitches = () => {
  return store.dispatch('config/getSwitches').then(response => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasWmiRules = () => {
  return store.dispatch('config/getWmiRules').then(response => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasWRIXLocations = () => {
  return store.dispatch('config/getWrixLocations').then(response => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const categoryIdNumberExists = (value) => {
  if (!value || !/^\d+$/.test(value)) return true
  return store.dispatch('config/getRoles').then(response => {
    if (response.length === 0) return true
    else return response.filter(role => role.category_id === value).length > 0
  }).catch(() => {
    return true
  })
}

export const categoryIdStringExists = (value) => {
  if (!value || /^\d+$/.test(value)) return true
  return store.dispatch('config/getRoles').then(response => {
    if (response.length === 0) return true
    else return response.filter(role => role.name.toLowerCase() === value.toLowerCase()).length > 0
  }).catch(() => {
    return true
  })
}

export const interfaceExists = (value) => {
  if (!value) return true
  return store.dispatch('config/getInterfaces').then(response => {
    if (response.length === 0) return true
    else return response.filter(iface => iface.id.toLowerCase() === value.toLowerCase()).length > 0
  }).catch(() => {
    return true
  })
}

export const interfaceVlanExists = (id) => {
  return (0, _common.withParams)({
    type: 'interfaceVlanExists',
    id
  }, function (value) {
    if (!(0, _common.req)(value)) return true
    return store.dispatch('config/getInterfaces').then(response => {
      if (id.includes('.')) { // split dot-notation `iface.vlan` to `iface` only.
        id = id.split('.')[0]
      }
      if (response.length === 0) return true
      else return response.filter(iface => iface.master === id && iface.vlan === value).length > 0
    }).catch(() => {
      return true
    })
  })
}

export const nodeExists = (value) => {
  if (!value) return true
  // standardize MAC address
  value = value.toLowerCase().replace(/[^0-9a-f]/g, '').split('').reduce((a, c, i) => {
    a += ((i % 2) === 0 || i >= 11) ? c : c + ':'
    return a
  })
  if (value.length !== 17) return true
  return store.dispatch('$_nodes/exists', value).then(() => {
    return false
  }).catch(() => {
    return true
  })
}

export const portalModuleExists = (value) => {
  if (!value) return true
  return store.dispatch('config/getPortalModules').then(response => {
    if (response.length === 0) return true
    else return response.filter(module => module.id.toLowerCase() === value.toLowerCase()).length > 0
  }).catch(() => {
    return true
  })
}

export const sourceExists = (value) => {
  if (!value) return true
  return store.dispatch('config/getSources').then(response => {
    if (response.length === 0) return true
    else return response.filter(source => source.id.toLowerCase() === value.toLowerCase()).length > 0
  }).catch(() => {
    return true
  })
}

export const switchExists = (value) => {
  if (!value) return true
  return store.dispatch('config/getSwitches').then(response => {
    if (response.length === 0) return true
    else return response.filter(switche => switche.id.toLowerCase() === value.toLowerCase()).length > 0
  }).catch(() => {
      return true
  })
}

export const switchNotExists = (value) => {
  if (!value) return true
  return store.dispatch('config/getSwitches').then((response) => {
    if (response.length === 0) return false
    else return response.filter(switche => switche.id.toLowerCase() === value.toLowerCase()).length === 0
  }).catch(() => {
      return true
  })
}

export const switchModeExists = (value) => {
  if (!value) return true
  return store.dispatch('$_switches/optionsBySwitchGroup', 'default').then((response) => {
    const { meta: { mode: { allowed } = {} } = {} } = response
    for (const { value: v } of allowed) {
      if (v === value) return true
    }
    return false
  }).catch(() => {
    return true
  })
}

export const switchTypeExists = (value) => {
  if (!value) return true
  return store.dispatch('$_switches/optionsBySwitchGroup', 'default').then((response) => {
    const { meta: { type: { allowed } = {} } = {} } = response
    for (const { options } of allowed) {
      for (let option of options) {
        const { value: v } = option
        if (v === value) return true
      }
    }
    return false
  }).catch(() => {
    return true
  })
}

export const userExists = (value) => {
  if (!value) return true
  return store.dispatch('$_users/exists', value).then(() => {
    return false
  }).catch(() => {
    return true
  })
}

export const userNotExists = (value) => {
  if (!value) return true
  return store.dispatch('$_users/exists', value).then(() => {
    return true
  }).catch(() => {
    return false
  })
}

export const wmiRuleExists = (value) => {
  if (!value) return true
  return store.dispatch('config/getWmiRules').then(response => {
    if (response.length === 0) return true
    else return response.filter(wmiRule => wmiRule.id.toLowerCase() === value.toLowerCase()).length > 0
  }).catch(() => {
    return true
  })
}

export const WRIXLocationExists = (value) => {
  if (!value) return true
  return store.dispatch('config/getWrixLocations').then(response => {
    if (response.length === 0) return true
    else return response.filter(wrixLocation => wrixLocation.id.toLowerCase() === value.toLowerCase()).length > 0
  }).catch(() => {
    return true
  })
}
