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
 *
 * Misc local helpers
 *
**/

// Get the unique id of a given $v.
const idOfV = ($v) => {
  if ($v.constructor === String) return undefined
  const { '__ob__': { dep: { id } } } = $v
  return id || undefined
}

/**
 *  Get the parent $v of a given id.
 *
 *  For use with "Field" functions.
 *  Searches for a member from a given |id|,
 *   starts with the base $v, and traverses the entire $v model tree recursively,
 *   returns the members' parent.
**/
const parentVofId = ($v, id) => {
  const params = Object.keys($v.$params)
  for (let i = 0; i < params.length; i++) {
    const param = params[i]
    if (typeof $v[param] === 'object' && typeof $v[param].$model === 'object') {
      if ($v[param].$model && '__ob__' in $v[param].$model) {
        if (idOfV($v[param].$model) === id) return $v
      }
      // recurse
      let $parent = parentVofId($v[param], id)
      if ($parent) return $parent
    }
  }
  return undefined
}

// Get the id, parent and params from a given $v member
const idParentParamsFromV = (vBase, vMember) => {
  const id = idOfV(vMember)
  const parent = (id) ? parentVofId(vBase, id) : undefined
  const params = (id) ? Object.entries(parent.$params) : undefined
  return { id: id, parent: parent, params: params }
}

/**
 * Default replacements - Fix Promises
**/

// Default vuelidate |and| replacement, handles Promises
export const and = (...validators) => {
  return _common.withParams({ type: 'and' }, function (...args) {
    return (
      validators.length > 0 &&
      Promise.all(validators.map(fn => fn.apply(this, args))).then(values => {
        return values.reduce((valid, value) => {
          return valid && value
        }, true)
      })
    )
  })
}

// Default vuelidate |or| replacement, handles Promises
export const or = (...validators) => {
  return _common.withParams({ type: 'and' }, function (...args) {
    return (
      validators.length > 0 &&
      Promise.all(validators.map(fn => fn.apply(this, args))).then(values => {
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
    return (conditional.constructor === Function)
      ? (typeof value === 'undefined')
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

export const isFilenameWithExtension = (extensions = ['html']) => {
  return (0, _common.withParams)({
    type: 'isFilenameWithExtension',
    extensions: extensions
  }, function (value) {
    const re = RegExp('^[a-zA-Z0-9_]*\\.(' + extensions.join('|') + ')$')
    return re.test(value)
  })
}

export const hasAdminRoles = (value, component) => {
  return store.dispatch('config/getAdminRoles').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasBillingTiers = (value, component) => {
  return store.dispatch('config/getBillingTiers').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasConnectionProfiles = (value, component) => {
  return store.dispatch('config/getConnectionProfiles').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasDeviceRegistrations = (value, component) => {
  return store.dispatch('config/getDeviceRegistrations').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasDomains = (value, component) => {
  return store.dispatch('config/getDomains').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasFirewalls = (value, component) => {
  return store.dispatch('config/getFirewalls').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasFloatingDevices = (value, component) => {
  return store.dispatch('config/getFloatingDevices').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasInterfaces = (value, component) => {
  return store.dispatch('config/getInterfaces').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasMaintenanceTasks = (value, component) => {
  return store.dispatch('config/getMaintenanceTasks').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasPkiProviders = (value, component) => {
  return store.dispatch('config/getPkiProviders').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasProvisionings = (value, component) => {
  return store.dispatch('config/getProvisionings').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasRealms = (value, component) => {
  return store.dispatch('config/getRealms').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasRoles = (value, component) => {
  return store.dispatch('config/getRoles').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasRoutedNetworks = (value, component) => {
  return store.dispatch('config/getRoutedNetworks').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasScans = (value, component) => {
  return store.dispatch('config/getScans').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasSecurityEvents = (value, component) => {
  return store.dispatch('config/getSecurityEvents').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasSources = (value, component) => {
  return store.dispatch('config/getSources').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasSwitches = (value, component) => {
  return store.dispatch('config/getSwitches').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasSwitchGroups = (value, component) => {
  return store.dispatch('config/getSwitchGroups').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasSyslogForwarders = (value, component) => {
  return store.dispatch('config/getSyslogForwarders').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasSyslogParsers = (value, component) => {
  return store.dispatch('config/getSyslogParsers').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasTrafficShapingPolicies = (value, component) => {
  return store.dispatch('config/getTrafficShapingPolicies').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasWmiRules = (value, component) => {
  return store.dispatch('config/getWmiRules').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const hasWRIXLocations = (value, component) => {
  return store.dispatch('config/getWrixLocations').then((response) => {
    return (response.length > 0)
  }).catch(() => {
    return true
  })
}

export const adminRoleExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getAdminRoles').then((response) => {
    return (response.filter(adminRole => adminRole.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const billingTierExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getBillingTiers').then((response) => {
    return (response.filter(billingTier => billingTier.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const categoryIdNumberExists = (value, component) => {
  if (!value || !/^\d+$/.test(value)) return true
  return store.dispatch('config/getRoles').then((response) => {
    if (response.length === 0) return true
    return (response.filter(role => role.category_id === value).length > 0)
  }).catch(() => {
    return true
  })
}

export const categoryIdStringExists = (value, component) => {
  if (!value || /^\d+$/.test(value)) return true
  return store.dispatch('config/getRoles').then((response) => {
    if (response.length === 0) return true
    return (response.filter(role => role.name.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const connectionProfileExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getConnectionProfiles').then((response) => {
    if (response.length === 0) return true
    return (response.filter(connectionProfile => connectionProfile.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const deviceRegistrationExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getDeviceRegistrations').then((response) => {
    if (response.length === 0) return true
    return (response.filter(deviceRegistration => deviceRegistration.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const domainExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getDomains').then((response) => {
    if (response.length === 0) return true
    return (response.filter(domain => domain.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const firewallExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getFirewalls').then((response) => {
    if (response.length === 0) return true
    return (response.filter(firewall => firewall.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const floatingDeviceExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getFloatingDevices').then((response) => {
    if (response.length === 0) return true
    return (response.filter(floatingDevice => floatingDevice.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const interfaceExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getInterfaces').then((response) => {
    if (response.length === 0) return true
    return (response.filter(iface => iface.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const interfaceVlanExists = (id) => {
  return (0, _common.withParams)({
    type: 'interfaceVlanExists',
    id: id
  }, function (value) {
    if (!(0, _common.req)(value)) return true
    return store.dispatch('config/getInterfaces').then((response) => {
      if (response.length === 0) return true
      return (response.filter(iface => iface.master === id && iface.vlan === value).length > 0)
    }).catch(() => {
      return true
    })
  })
}

export const fingerbankCombinationExists = (value, component) => {
  if (!value) return true
  return store.dispatch('fingerbank/getCombination', value).then(() => {
    return true
  }).catch(() => {
    return false
  })
}

export const nodeExists = (value, component) => {
  if (!value || value.length !== 17) return true
  return store.dispatch('$_nodes/exists', value).then(() => {
    return false
  }).catch(() => {
    return true
  })
}

export const maintenanceTaskExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getMaintenanceTasks').then((response) => {
    if (response.length === 0) return true
    return (response.filter(maintenanceTask => maintenanceTask.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const pkiProviderExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getPkiProviders').then((response) => {
    if (response.length === 0) return true
    return (response.filter(provider => provider.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const provisioningExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getProvisionings').then((response) => {
    if (response.length === 0) return true
    return (response.filter(provisioning => provisioning.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const realmExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getRealms').then((response) => {
    if (response.length === 0) return true
    return (response.filter(realm => realm.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const roleExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getRoles').then((response) => {
    if (response.length === 0) return true
    return (response.filter(role => role.name.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const routedNetworkExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getRoutedNetworks').then((response) => {
    if (response.length === 0) return true
    return (response.filter(routedNetwork => routedNetwork.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const scanExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getScans').then((response) => {
    if (response.length === 0) return true
    return (response.filter(scan => scan.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const securityEventExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getSecurityEvents').then((response) => {
    if (response.length === 0) return true
    return (response.filter(securityEvent => securityEvent.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const sourceExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getSources').then((response) => {
    if (response.length === 0) return true
    return (response.filter(source => source.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const switchExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getSwitches').then((response) => {
    if (response.length === 0) return true
    return (response.filter(switche => switche.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const switchGroupExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getSwitchGroups').then((response) => {
    if (response.length === 0) return true
    return (response.filter(switchGroup => switchGroup.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const syslogForwarderExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getSyslogForwarders').then((response) => {
    if (response.length === 0) return true
    return (response.filter(syslogForwarder => syslogForwarder.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const syslogParserExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getSyslogParsers').then((response) => {
    if (response.length === 0) return true
    return (response.filter(syslogParser => syslogParser.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const trafficShapingPolicyExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getTrafficShapingPolicies').then((response) => {
    if (response.length === 0) return true
    return (response.filter(trafficShapingPolicy => trafficShapingPolicy.id.toLowerCase() === value.toLowerCase()).length > 0)
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

export const userNotExists = (value, component) => {
  if (!value) return true
  return store.dispatch('$_users/exists', value).then(results => {
    return false
  }).catch(() => {
    return true
  })
}

export const wmiRuleExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getWmiRules').then((response) => {
    if (response.length === 0) return true
    return (response.filter(wmiRule => wmiRule.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

export const WRIXLocationExists = (value, component) => {
  if (!value) return true
  return store.dispatch('config/getWrixLocations').then((response) => {
    if (response.length === 0) return true
    return (response.filter(wrixLocation => wrixLocation.id.toLowerCase() === value.toLowerCase()).length > 0)
  }).catch(() => {
    return true
  })
}

/**
 * Field functions
 *
 * For use with pfFormField component.
 * Used to validate |key| fields with immediate siblings.
 * All functions ignore self.
**/

// Limit the count of sibling field |keys|
export const limitSiblingFields = (keys, limit = 0) => {
  return (0, _common.withParams)({
    type: 'limitSiblingFields',
    keys: keys,
    limit: limit
  }, function (value, field) {
    if (!value) return true
    const _keys = (keys.constructor === Array) ? keys : [keys] // force Array
    let count = 0
    const { id, parent, params } = idParentParamsFromV(this.$v, field)
    if (params) {
      // iterate through all params
      for (let i = 0; i < params.length; i++) {
        const [param] = params[i] // destructure
        if (!parent[param].$model) continue // ignore empty models
        if (idOfV(parent[param].$model) === id) continue // ignore (self)
        // iterate through all keys, continue on 1st mismatch
        if (_keys.find(key => {
          return parent[param].$model[key] !== field[key]
        })) {
          continue // GTFO
        }
        if (++count > limit) return false
      }
    }
    return true
  })
}

// Require all of sibling field |key|s
export const requireAllSiblingFields = (key, ...fieldTypes) => {
  return (0, _common.withParams)({
    type: 'requireAllSiblingFields',
    key: key,
    fieldTypes: fieldTypes
  }, function (value, field) {
    if (!value) return true
    // dereference, preserve original
    let _fieldTypes = JSON.parse(JSON.stringify(fieldTypes))
    const { id, parent, params } = idParentParamsFromV(this.$v, field)
    if (params) {
      // iterate through all params
      for (let i = 0; i < params.length; i++) {
        const [param] = params[i] // destructure
        if (!parent[param].$model) continue // ignore empty models
        if (idOfV(parent[param].$model) === id) continue // ignore (self)
        // iterate through _fieldTypes and substitute
        _fieldTypes = _fieldTypes.map(fieldType => {
          // substitute the fieldType with |true| if it exists
          return (parent[param].$model[key] === fieldType) ? true : fieldType
        })
      }
    }
    // return |true| if all members of the the array are |true|,
    // anything else return false
    return _fieldTypes.reduce((bool, fieldType) => { return bool && (fieldType === true) }, true)
  })
}

// Require any of sibling field |key|s
export const requireAnySiblingFields = (key, ...fieldTypes) => {
  return (0, _common.withParams)({
    type: 'requireAnySiblingFields',
    key: key,
    fieldTypes: fieldTypes
  }, function (value, field) {
    if (!value) return true
    // dereference, preserve original
    let _fieldTypes = JSON.parse(JSON.stringify(fieldTypes))
    const { id, parent, params } = idParentParamsFromV(this.$v, field)
    if (params) {
      // iterate through all params
      for (let i = 0; i < params.length; i++) {
        const [param] = params[i] // destructure
        if (!parent[param].$model) continue // ignore empty models
        if (idOfV(parent[param].$model) === id) continue // ignore (self)
        // return |true| if any fieldType exists
        if (_fieldTypes.includes(parent[param].$model[key])) return true
      }
    }
    // otherwise return false
    return false
  })
}

// Restrict all of sibling field |key|s
export const restrictAllSiblingFields = (key, ...fieldTypes) => {
  return (0, _common.withParams)({
    type: 'restrictAllSiblingFields',
    key: key,
    fieldTypes: fieldTypes
  }, function (value, field) {
    if (!value) return true
    // dereference, preserve original
    let _fieldTypes = JSON.parse(JSON.stringify(fieldTypes))
    const { id, parent, params } = idParentParamsFromV(this.$v, field)
    if (params) {
      // iterate through all params
      for (let i = 0; i < params.length; i++) {
        const [param] = params[i] // destructure
        if (!parent[param].$model) continue // ignore empty models
        if (idOfV(parent[param].$model) === id) continue // ignore (self)
        // iterate through _fieldTypes and substitute
        _fieldTypes = _fieldTypes.map(fieldType => {
          // substitute the fieldType with |true| if it exists
          return (parent[param].$model[key] === fieldType) ? true : fieldType
        })
      }
    }
    // return |false| if all members of the the array are |true|,
    // anything else return true
    return !_fieldTypes.reduce((bool, fieldType) => { return bool && (fieldType === true) }, true)
  })
}

// Restrict any of sibling field |key|s
export const restrictAnySiblingFields = (key, ...fieldTypes) => {
  return (0, _common.withParams)({
    type: 'restrictAnySiblingFieldTypes',
    key: key,
    fieldTypes: fieldTypes
  }, function (value, field) {
    if (!value) return true
    // dereference, preserve original
    let _fieldTypes = JSON.parse(JSON.stringify(fieldTypes))
    const { id, parent, params } = idParentParamsFromV(this.$v, field)
    if (params) {
      // iterate through all params
      for (let i = 0; i < params.length; i++) {
        const [param] = params[i] // destructure
        if (!parent[param].$model) continue // ignore empty models
        if (idOfV(parent[param].$model) === id) continue // ignore (self)
        // return |false| if any fieldType exists
        if (_fieldTypes.includes(parent[param].$model[key])) return false
      }
    }
    // otherwise return true
    return true
  })
}
