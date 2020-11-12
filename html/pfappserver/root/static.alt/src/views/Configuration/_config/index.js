import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import {
  isPattern
} from '@/globals/pfValidators'
const {
  integer,
  minLength,
  maxLength,
  maxValue,
  minValue,
  required
} = require('vuelidate/lib/validators')

export const optionsSearchFunction = (context) => {
  const { field_name: fieldName, value_name: valueName, search_path: url } = context
  return function (chosen, query, searchById = false) {
    if (!query) return []
    return apiCall.post(
      url,
      {
        query: {
          op: 'and',
          values: [{
            op: 'or',
            values: ((searchById)
              // search by identifier
              ? ((query.constructor === Array) ? query : [query]).map(value => {
                return { field: valueName, op: 'equals', value: `${(value).toString().trim()}` }
              })
              // search by user defined string
              : [{ field: fieldName, op: 'contains', value: `${(query).toString().trim()}` }]
            )
          }]
        },
        fields: [fieldName, valueName],
        sort: [fieldName],
        cursor: 0,
        limit: 100
      },
      {
        baseURL: '' // reset
      }
    ).then(response => {
      return response.data.items.map(item => {
        return { [chosen.trackBy]: item[valueName].toString(), [chosen.label]: item[fieldName] }
      })
    })
  }
}

export const attributesFromMeta = (meta = {}, key = null) => {
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
    let { [key]: { allowed, allow_custom, allowed_lookup: allowedLookup, placeholder, type, item } = {} } = meta
    switch (type) {
      case 'array':
        attrs.multiple = true // pfFormChosen
        attrs.clearOnSelect = false // pfFormChosen
        attrs.closeOnSelect = false // pfFormChosen
        if (allow_custom) attrs.taggable = true // pfFormChosen
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
    if (allow_custom) attrs.taggable = true // pfFormChosen
    if (allowed) attrs.options = allowed
    else if (allowedLookup) {
      attrs.searchable = true
      attrs.internalSearch = false
      attrs.preserveSearch = false
      attrs.allowEmpty = (!(key in meta && 'required' in Object.keys(meta[key])))
      attrs.clearOnSelect = false
      attrs.placeholder = i18n.t('Type to search.')
      attrs.showNoOptions = false
      attrs.optionsSearchFunction = (chosen, query, searchById) => { // wrap function
        const f = optionsSearchFunction(allowedLookup)
        if (!query) {
          switch (key) {
            case 'devices_included': // include common os choices
            case 'devices_excluded': // include common os choices
            case 'oses': // include common os choices
              return [...new Set(
                [
                  ...[
                    { text: 'Windows Phone OS', value: '33507' },
                    { text: 'Mac OS X or macOS', value: '2' },
                    { text: 'Android OS', value: '33453' },
                    { text: 'Windows OS', value: '1' },
                    { text: 'BlackBerry OS', value: '33471' },
                    { text: 'iOS', value: '33450' },
                    { text: 'Linux OS', value: '5' }
                  ],
                  ...f(chosen, query, searchById)
                ]
              )]
          }
        }
        return f(chosen, query, searchById)
      }
    }
  }
  return attrs
}

export const defaultsFromMeta = (meta = {}) => {
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

export const authenticationSourceRulesConditionFieldsFromMeta = (meta = {}, key = null) => {
  let fields = []
  if (Object.keys(meta).length > 0) {
    while (key.includes('.')) { // handle dot-notation keys ('.')
      let [ first, ...remainder ] = key.split('.')
      if (!(first in meta)) return {}
      key = remainder.join('.')
      let { [first]: { item: { properties } = {} } } = meta
      if (properties) {
        meta = properties // swap ref to child
      }
    }
    let { [key]: { allowed } = {} } = meta
    if (allowed) {
      allowed.forEach((item) => {
        const { text, value, attributes: { 'data-type': type } = {} } = item
        fields.push({
          text: i18n.t(text),
          value,
          types: [type],
          validators: {
            operator: {
              [i18n.t('Operator required.')]: required
            },
            value: {
              [i18n.t('Value required.')]: required,
              [i18n.t('Maximum 255 characters.')]: maxLength(255)
            }
          }
        })
      })
    }
  }
  return fields
}

export const validatorsFromMeta = (meta = {}, path = null, fieldName = 'Value') => {
  let validators = {}
  let key = path
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
          case 'allow_custom': // ignore
          case 'required_when': // ignore
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
            validators = { ...validators, ...{ [meta[key].pattern.message]: isPattern(meta[key].pattern.regex) } }
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
              default:
                // eslint-disable-next-line
                console.error(`Unhandled meta type @${path}: ${meta[key].type}`)
                // break
            }
            break
          default:
            // eslint-disable-next-line
            console.error(`Unhandled meta @${path}: ${property}`)
            // break
        }
      })
    }
  }
  return validators
}
