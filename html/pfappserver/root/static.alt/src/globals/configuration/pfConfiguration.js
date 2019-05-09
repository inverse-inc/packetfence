import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import bytes from '@/utils/bytes'
import pfFormInput from '@/components/pfFormInput'
import { pfAuthenticationConditionType as authenticationConditionType } from '@/globals/pfAuthenticationConditions'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import {
  alphaNum,
  and,
  not,
  conditional,
  compareDate,
  isDateFormat,
  hasSources,
  sourceExists,
  requireAllSiblingFields,
  requireAnySiblingFields,
  restrictAllSiblingFields,
  limitSiblingFields,
  isPattern
} from '@/globals/pfValidators'

const {
  integer,
  minLength,
  maxLength,
  maxValue,
  minValue,
  numeric,
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationOptionsSearchFunction = (context) => {
  const { field_name: fieldName, value_name: valueName, search_path: url } = context
  return function (chosen, query) {
    let currentOptions = []
    if (chosen.value) {
      currentOptions = (chosen.multiple) // cache current value
        ? chosen.options.filter(option => chosen.value.includes(option[chosen.trackBy])) // multiple
        : chosen.options.find(option => option[chosen.trackBy] === chosen.value) // single
    }
    if (!query) return currentOptions
    if (!chosen.optionsSearchFunctionInitialized) { // first query - presearch current value
      return apiCall.request({
        url,
        method: 'post',
        baseURL: '', // reset
        data: {
          query: {
            op: 'and',
            values: [{
              op: 'or',
              values: ((query.constructor === Array) ? query : [query]).map(value => {
                return { field: valueName, op: 'equals', value: `${value.trim()}` }
              })
            }]
          },
          fields: [fieldName, valueName],
          sort: [fieldName],
          cursor: 0,
          limit: 100
        }
      }).then(response => {
        return response.data.items.map(item => {
          return { [chosen.trackBy]: item[valueName].toString(), [chosen.label]: item[fieldName] }
        })
      })
    } else { // subsequent queries
      return apiCall.request({
        url,
        method: 'post',
        baseURL: '', // reset
        data: {
          query: { op: 'and', values: [{ op: 'or', values: [{ field: fieldName, op: 'contains', value: `${query.trim()}` }] }] },
          fields: [fieldName, valueName],
          sort: [fieldName],
          cursor: 0,
          limit: chosen.optionsLimit - currentOptions.length
        }
      }).then(response => {
        return [
          ...((currentOptions) ? [...currentOptions] : []), // current option first
          ...response.data.items.map(item => {
            return { [chosen.trackBy]: item[valueName].toString(), [chosen.label]: item[fieldName] }
          }).filter(item => {
            return JSON.stringify(item) !== JSON.stringify(currentOptions) // remove duplicate current option
          })
        ]
      })
    }
  }
}

export const pfConfigurationAttributesFromMeta = (meta = {}, key = null) => {
  let attrs = {}
  if (Object.keys(meta).length > 0) {
    while (key.includes('.')) { // handle dot-notation keys ('.')
      let [ first, ...remainder ] = key.split('.')
      if (!(first in meta)) return {}
      key = remainder.join('.')
      let { [first]: { item: { properties: _collectionMeta } = {}, properties: _meta } } = meta
      if (_collectionMeta) {
        meta = _collectionMeta // swap ref to child
      } else {
        meta = _meta // swap ref to child
      }
    }
    let { [key]: { allowed, allowed_lookup: allowedLookup, placeholder, type, item } = {} } = meta
    switch (type) {
      case 'array':
        attrs.multiple = true // pfFormChosen
        attrs.clearOnSelect = false // pfFormChosen
        attrs.closeOnSelect = false // pfFormChosen
        if (item) {
          const { allowed: itemAllowed, allowed_lookup: itemAllowedLookup } = item
          if (itemAllowed) allowed = itemAllowed
          else if (itemAllowedLookup) allowedLookup = itemAllowedLookup
        }
        break
      case 'integer':
        attrs.type = 'number' // pfFormInput
        attrs.step = 1 // pfFormInput
        break
    }
    if (placeholder) attrs.placeholder = placeholder
    if (allowed) attrs.options = allowed
    else if (allowedLookup) {
      attrs.searchable = true
      attrs.internalSearch = false
      attrs.preserveSearch = false
      attrs.allowEmpty = (!(key in meta && 'required' in Object.keys(meta[key])))
      attrs.clearOnSelect = true
      attrs.placeholder = i18n.t('Type to search')
      attrs.showNoOptions = false
      attrs.optionsSearchFunction = (chosen, query) => { // wrap function
        const f = pfConfigurationOptionsSearchFunction(allowedLookup)
        if (query) {
          return f(chosen, query)
        } else {
          switch (key) {
            case 'oses':
              return [
                ...[
                  { text: 'Windows Phone OS', value: '33507' },
                  { text: 'Mac OS X or macOS', value: '2' },
                  { text: 'Android OS', value: '33453' },
                  { text: 'Windows OS', value: '1' },
                  { text: 'BlackBerry OS', value: '33471' },
                  { text: 'iOS', value: '33450' },
                  { text: 'Linux OS', value: '5' }
                ],
                ...f(chosen, query)
              ]
            default:
              return f(chosen, query)
          }
        }
      }
    }
  }
  return attrs
}

export const pfConfigurationDefaultsFromMeta = (meta = {}) => {
  let defaults = {}
  Object.keys(meta).forEach(key => {
    if ('properties' in meta[key]) { // handle dot-notation keys ('.')
      Object.keys(meta[key].properties).forEach(property => {
        if (!(key in defaults)) {
          defaults[key] = {}
        }
        // default w/ object
        defaults[key][property] = meta[key].properties[property].default
      })
    } else {
      defaults[key] = meta[key].default
    }
  })
  return defaults
}

export const pfConfigurationValidatorsFromMeta = (meta = {}, key = null, fieldName = 'Value') => {
  let validators = {}
  if (Object.keys(meta).length > 0) {
    while (key.includes('.')) { // handle dot-notation keys ('.')
      let [ first, ...remainder ] = key.split('.')
      if (!(first in meta)) return {}
      key = remainder.join('.')
      let { [first]: { item: { properties: _collectionMeta } = {}, properties: _meta } } = meta
      if (_collectionMeta) {
        meta = _collectionMeta // swap ref to child
      } else {
        meta = _meta // swap ref to child
      }
    }
    if (key in meta) {
      Object.keys(meta[key]).forEach(property => {
        switch (property) {
          case 'allowed': // ignore
          case 'default': // ignore
          case 'placeholder': // ignore
          case 'allowed_lookup': // ignore
            break
          case 'item': // ignore
            // TODO
            break
          case 'min_value':
            validators = { ...validators, ...{ [i18n.t('Minimum {minValue}.', { minValue: meta[key].min_value })]: minValue(meta[key].min_value) } }
            break
          case 'max_value':
            validators = { ...validators, ...{ [i18n.t('Maximum {maxValue}.', { maxValue: meta[key].max_value })]: maxValue(meta[key].max_value) } }
            break
          case 'min_length':
            validators = { ...validators, ...{ [i18n.t('Minimum {minLength} characters.', { minLength: meta[key].min_length })]: minLength(meta[key].min_length) } }
            break
          case 'max_length':
            validators = { ...validators, ...{ [i18n.t('Maximum {maxLength} characters.', { maxLength: meta[key].max_length })]: maxLength(meta[key].max_length) } }
            break
          case 'pattern':
            validators = { ...validators, ...{ [i18n.t('Invalid {fieldName}.', { fieldName: meta[key].pattern.message })]: isPattern(meta[key].pattern.regex) } }
            break
          case 'required':
            if (meta[key].required === true) { // only if `true`
              validators = { ...validators, ...{ [i18n.t('{fieldName} required.', { fieldName: fieldName })]: required } }
            }
            break
          case 'type':
            switch (meta[key].type) {
              case 'integer':
                validators = { ...validators, ...{ [i18n.t('Integers only.')]: integer } }
                break
              case 'array': // ignore
              case 'string': // ignore
                break
              default: // TODO: remove post-devel
                throw new Error(`Unhandled meta type: ${meta[key].type}`)
                // break
            }
            break
          default: // TODO: remove post-devel
            throw new Error(`Unhandled meta: ${property}`)
            // break
        }
      })
    }
  }
  return validators
}

export const pfConfigurationLocales = [
  'en_US',
  'de_DE',
  'es_ES',
  'fr_CA',
  'fr_FR',
  'he_IL',
  'it_IT',
  'nl_NL',
  'pl_PL',
  'pt_BR'
].map(locale => { return { text: locale, value: locale } })

export const pfConfigurationActions = {
  set_access_duration: {
    value: 'set_access_duration',
    text: i18n.t('Access duration'),
    types: [fieldType.DURATION],
    validators: {
      type: {
        /* Require "set_role" */
        [i18n.t('Action requires "Set Role".')]: requireAllSiblingFields('type', 'set_role'),
        /* Restrict "set_unreg_date" */
        [i18n.t('Action conflicts with "Unregistration date".')]: restrictAllSiblingFields('type', 'set_unreg_date'),
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_access_level: {
    value: 'set_access_level',
    text: i18n.t('Access level'),
    types: [fieldType.ADMINROLE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_bandwidth_balance: {
    value: 'set_bandwidth_balance',
    text: i18n.t('Bandwidth balance'),
    types: [fieldType.PREFIXMULTIPLIER],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Value must be greater than {min}bytes.', { min: bytes.toHuman(schema.node.bandwidth_balance.min) })]: minValue(schema.node.bandwidth_balance.min),
        [i18n.t('Value must be less than {max}bytes.', { max: bytes.toHuman(schema.node.bandwidth_balance.max) })]: maxValue(schema.node.bandwidth_balance.max)
      }
    }
  },
  mark_as_sponsor: {
    value: 'mark_as_sponsor',
    text: i18n.t('Mark as sponsor'),
    types: [fieldType.NONE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      }
    }
  },
  set_role: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE],
    validators: {
      type: {
        /* When "Role" is selected, either "Time Balance" or "set_unreg_date" is required */
        [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: requireAnySiblingFields('type', 'set_access_duration', 'set_unreg_date'),
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_role_by_name: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE_BY_NAME],
    validators: {
      type: {
        /* When "Role" is selected, either "Time Balance" or "set_unreg_date" is required */
        [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: requireAnySiblingFields('type', 'set_access_duration', 'set_unreg_date'),
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_tenant_id: {
    value: 'set_tenant_id',
    text: i18n.t('Tenant ID'),
    types: [fieldType.TENANT],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Value must be numeric.')]: numeric
      }
    }
  },
  set_time_balance: {
    value: 'set_time_balance',
    text: i18n.t('Time balance'),
    types: [fieldType.TIME_BALANCE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_unreg_date: {
    value: 'set_unreg_date',
    text: i18n.t('Unregistration date'),
    types: [fieldType.DATETIME],
    moments: ['1 days', '1 weeks', '1 months', '1 years'],
    validators: {
      type: {
        /* Require "set_role" */
        [i18n.t('Action requires "Set Role".')]: requireAllSiblingFields('type', 'set_role'),
        /* Restrict "set_access_duration" */
        [i18n.t('Action conflicts with "Access duration".')]: restrictAllSiblingFields('type', 'set_access_duration'),
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Future date required.')]: compareDate('>=', new Date(), schema.node.unregdate.format, false),
        [i18n.t('Invalid date.')]: isDateFormat(schema.node.unregdate.format)
      }
    }
  }
}

export const pfConfigurationConditions = {
  'Called-Station-Id': {
    value: 'Called-Station-Id',
    text: i18n.t('Called-Station-Id'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'Calling-Station-Id': {
    value: 'Calling-Station-Id',
    text: i18n.t('Calling-Station-Id'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  cn: {
    value: 'cn',
    text: i18n.t('cn'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  computer_name: {
    value: 'computer_name',
    text: i18n.t('Computer Name'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  connection_type: {
    value: 'connection_type',
    text: i18n.t('Connection type'),
    types: [authenticationConditionType.CONNECTION],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  current_time: {
    value: 'current_time',
    text: i18n.t('Current time'),
    types: [authenticationConditionType.TIME],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  current_time_period: {
    value: 'current_time_period',
    text: i18n.t('Current time period'),
    types: [authenticationConditionType.TIMEPERIOD],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  department: {
    value: 'department',
    text: i18n.t('department'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  description: {
    value: 'description',
    text: i18n.t('description'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  displayName: {
    value: 'displayName',
    text: i18n.t('displayName'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  distinguishedName: {
    value: 'distinguishedName',
    text: i18n.t('distinguishedName'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  eduPersonPrimaryAffiliation: {
    value: 'eduPersonPrimaryAffiliation',
    text: i18n.t('eduPersonPrimaryAffiliation'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  givenName: {
    value: 'givenName',
    text: i18n.t('givenName'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  group_header: {
    value: 'group_header',
    text: i18n.t('group_header Name'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  groupMembership: {
    value: 'groupMembership',
    text: i18n.t('groupMembership'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  mac: {
    value: 'mac',
    text: i18n.t('MAC Address'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  mail: {
    value: 'mail',
    text: i18n.t('mail'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  memberOf: {
    value: 'memberOf',
    text: i18n.t('memberOf'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'NAS-Identifier': {
    value: 'NAS-Identifier',
    text: i18n.t('NAS-Identifier'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  nested_group: {
    value: 'memberOf:1.2.840.113556.1.4.1941:',
    text: i18n.t('nested group'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  phonenumber: {
    value: 'phonenumber',
    text: i18n.t('phonenumber'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  postOfficeBox: {
    value: 'postOfficeBox',
    text: i18n.t('postOfficeBox'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  realm: {
    value: 'realm',
    text: i18n.t('Realm'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  sAMAccountName: {
    value: 'sAMAccountName',
    text: i18n.t('sAMAccountName'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  sAMAccountType: {
    value: 'sAMAccountType',
    text: i18n.t('sAMAccountType'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  servicePrincipalName: {
    value: 'servicePrincipalName',
    text: i18n.t('servicePrincipalName'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  sn: {
    value: 'sn',
    text: i18n.t('sn'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  SSID: {
    value: 'SSID',
    text: i18n.t('SSID'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Cert-Common-Name': {
    value: 'TLS-Cert-Common-Name',
    text: i18n.t('TLS-Cert-Common-Name'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Cert-Expiration': {
    value: 'TLS-Cert-Expiration',
    text: i18n.t('TLS-Cert-Expiration'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-Common-Name': {
    value: 'TLS-Client-Cert-Common-Name',
    text: i18n.t('TLS-Client-Cert-Common-Name'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-Expiration': {
    value: 'TLS-Client-Cert-Expiration',
    text: i18n.t('TLS-Client-Cert-Expiration'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-Filename': {
    value: 'TLS-Client-Cert-Filename',
    text: i18n.t('TLS-Client-Cert-Filename'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-Issuer': {
    value: 'TLS-Client-Cert-Issuer',
    text: i18n.t('TLS-Client-Cert-Issuer'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-Serial': {
    value: 'TLS-Client-Cert-Serial',
    text: i18n.t('TLS-Client-Cert-Serial'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-Subject': {
    value: 'TLS-Client-Cert-Subject',
    text: i18n.t('TLS-Client-Cert-Subject'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Cert-Issuer': {
    value: 'TLS-Cert-Issuer',
    text: i18n.t('TLS-Cert-Issuer'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Cert-Serial': {
    value: 'TLS-Cert-Serial',
    text: i18n.t('TLS-Cert-Serial'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Cert-Subject': {
    value: 'TLS-Cert-Subject',
    text: i18n.t('TLS-Cert-Subject'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-Subject-Alt-Name-Dns': {
    value: 'TLS-Client-Cert-Subject-Alt-Name-Dns',
    text: i18n.t('TLS-Client-Cert-Subject-Alt-Name-Dns'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-Subject-Alt-Name-Email': {
    value: 'TLS-Client-Cert-Subject-Alt-Name-Email',
    text: i18n.t('TLS-Client-Cert-Subject-Alt-Name-Email'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  'TLS-Client-Cert-X509v3-Extended-Key-Usage': {
    value: 'TLS-Client-Cert-X509v3-Extended-Key-Usage',
    text: i18n.t('TLS-Client-Cert-X509v3-Extended-Key-Usage'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  uid: {
    value: 'uid',
    text: i18n.t('uid'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  user_email: {
    value: 'user_email',
    text: i18n.t('user_email'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  userAccountControl: {
    value: 'userAccountControl',
    text: i18n.t('userAccountControl'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  UserPrincipalName: {
    value: 'UserPrincipalName',
    text: i18n.t('UserPrincipalName'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  username: {
    value: 'username',
    text: i18n.t('username'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  }
}

export const pfConfigurationViewFields = {
  id: ({ isNew = false, isClone = false } = {}) => {
    return {
      label: i18n.t('Name'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew && !isClone)
          },
          validators: {
            [i18n.t('Value required.')]: required,
            [i18n.t('Maximum 255 characters.')]: maxLength(255),
            [i18n.t('Alphanumeric characters only.')]: alphaNum,
            [i18n.t('Source exists.')]: not(and(required, conditional(isNew || isClone), hasSources, sourceExists))
          }
        }
      ]
    }
  },
  desc: {
    label: i18n.t('Description'),
    fields: [
      {
        key: 'desc',
        component: pfFormInput,
        validators: {
          [i18n.t('Description required.')]: required
        }
      }
    ]
  },
  description: {
    label: i18n.t('Description'),
    fields: [
      {
        key: 'description',
        component: pfFormInput,
        validators: {
          [i18n.t('Description required.')]: required
        }
      }
    ]
  }
}
