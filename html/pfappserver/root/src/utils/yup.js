import * as yup from 'yup'
import { parse, format, isValid, compareAsc } from 'date-fns'
import mime from 'mime-types'
import i18n from './locale'
import {
  reAlphaNumeric,
  reAlphaNumericHyphenUnderscoreDot,
  reCommonName,
  reEmail,
  reDomain,
  reIpv4,
  reIpv6,
  reFilename,
  reMac,
  reNumeric,
  reStaticRoute,
} from './regex'

yup.setLocale({ // default validators
  mixed: {
    required: args => args.message || i18n.t('{path} required.', args)
  },
  string: {
    email: args => args.message || i18n.t('Invalid Email.'),
    min: args => args.message || i18n.t('Minimum {min} characters.', args),
    max: args => args.message || i18n.t('Maximum {max} characters.', args),
    required: args => args.message || i18n.t('Value required.')
  }
})

/**
 * yup.array
**/
yup.addMethod(yup.array, 'if', function (cmpFn, message) {
  return this.test({
    name: 'required',
    message: message || i18n.t('Invalid value.'),
    test: value => cmpFn(value)
  })
})

yup.addMethod(yup.array, 'required', function (message) {
  return this.test({
    name: 'required',
    message: message || i18n.t('${path} required.'),
    test: value => (value && value.length > 0)
  })
})

yup.addMethod(yup.array, 'unique', function (message, hashFn) {
  hashFn = hashFn || JSON.stringify
  return this.test({
    name: 'unique',
    message: message || i18n.t('Duplicate item, must be unique.'),
    test: value => {
      if (!value || value.length === 0)
        return true
      let cmp = []
      for (let m = 0; m < value.length; m++) {
        let hash = hashFn(value[m])
        if (cmp.includes(hash))
          return false
        if (hash)
          cmp.push(hash)
      }
      return true
    }
  })
})

yup.addMethod(yup.array, 'ifThenRequires', function (message, ifIterFn, requiresIterFn) {
  return this.test({
    name: 'ifThenRequires',
    message: message || i18n.t('Missing value.'),
    test: value => {
      if (!value || value.length === 0)
        return true
      if (value.filter(row => ifIterFn(row)).length > 0)
        return (value.filter(row => requiresIterFn(row)).length > 0)
      return true
    }
  })
})

yup.addMethod(yup.array, 'ifThenRestricts', function (message, ifIterFn, restrictsIterFn) {
  return this.test({
    name: 'ifThenRestricts',
    message: message || i18n.t('Missing value.'),
    test: value => {
      if (!value || value.length === 0)
        return true
      if (value.filter(row => ifIterFn(row)).length > 0)
        return (value.filter(row => restrictsIterFn(row)).length === 0)
      return true
    }
  })
})

/**
 * yup.string
**/
yup.addMethod(yup.string, 'in', function (ref, message) {
  return this.test({
    name: 'in',
    message: message || i18n.t('Invalid value'),
    test: value => ref.includes(value)
  })
})

yup.addMethod(yup.string, 'not', function (cmp, message) {
  return this.test({
    name: 'not',
    message: message || i18n.t('Invalid value'),
    test: value => {
      return Promise.resolve((cmp.constructor === Function) ? cmp(value) : cmp)
    }
  })
})

yup.addMethod(yup.string, 'maxAsInt', function (ref, message) {
  return this.test({
    name: 'maxAsInt',
    message: message || i18n.t('Maximum {maxValue}.', { maxValue: ref }),
    test: value => ['', null, undefined].includes(value) || +value <= +ref
  })
})

yup.addMethod(yup.string, 'minAsInt', function (ref, message) {
  return this.test({
    name: 'minAsInt',
    message: message || i18n.t('Minimum {minValue}.', { minValue: ref }),
    test: value => ['', null, undefined].includes(value) || +value >= +ref
  })
})

yup.addMethod(yup.string, 'isAlphaNumeric', function (message) {
  return this.test({
    name: 'isAlphaNumeric',
    message: message || i18n.t('Invalid character, only letters (A-Z) or numbers (0-9).'),
    test: value => ['', null, undefined].includes(value) || reAlphaNumeric(value)
  })
})

yup.addMethod(yup.string, 'isAlphaNumericHyphenUnderscoreDot', function (message) {
  return this.test({
    name: 'isAlphaNumericHyphenUnderscoreDot',
    message: message || i18n.t('Invalid character, only letters (A-Z), numbers (0-9), hyphen (-), underscore (_), or dot (.).'),
    test: value => ['', null, undefined].includes(value) || reAlphaNumericHyphenUnderscoreDot(value)
  })
})

yup.addMethod(yup.string, 'isCIDR', function (message) {
  return this.test({
    name: 'isCIDR',
    message: message || i18n.t('Invalid CIDR.'),
    test: value => {
      if (['', null, undefined].includes(value))
        return true
      const [ipv4, network, ...extra] = value.split('/')
      return (
        extra.length === 0 &&
        !!network && +network >= 0 && +network <= 32 &&
        reIpv4(ipv4)
      )
    }
  })
})

export const isCommonName = value => (['', null, undefined].includes(value) || reCommonName(value))

yup.addMethod(yup.string, 'isCommonName', function (message) {
  return this.test({
    name: 'isCommonName',
    message: message || i18n.t('Invalid character, only letters (A-Z), numbers (0-9), hyphen (-), underscores (_), or colons (:).'),
    test: isCommonName
  })
})

yup.addMethod(yup.string, 'isCommonNameOrFQDN', function (message) {
  return this.test({
    name: 'isCommonNameOrFQDN',
    message: message || i18n.t('Invalid common name.'),
    test: (value) => (isCommonName(value) || isFQDN(value))
  })
})

yup.addMethod(yup.string, 'isCommonNameOrFQDNOrMAC', function (message) {
  const ALLOW_WILDCARD = true
  return this.test({
    name: 'isCommonNameOrFQDNOrMAC',
    message: message || i18n.t('Invalid common name.'),
    test: (value) => (isCommonName(value) || isFQDN(value, ALLOW_WILDCARD) || `${value}`.toLowerCase().replace(/[^0-9a-f]/g, '').length === 12)
  })
})

yup.addMethod(yup.string, 'isDateCompare', function (comparison, date = new Date(), dateFormat = 'YYYY-MM-DD HH:mm:ss', message) {
  return this.test({
    name: 'isDateCompare',
    message: i18n.t('Invalid date.'),
    test: function (value) {
      if (['', null, undefined].includes(value) || ['', null, undefined].includes(date))
        return true
      // handle zero dates (substitute with max)
      if ([0, '0'].includes(value))
        value = new Date(8640000000000000)
      if ([0, '0'].includes(date))
        date = new Date(8640000000000000)
      // round date/value using date-fns format
      const _date = format((date instanceof Date && isValid(date) ? date : parse(date)), dateFormat)
      const _value = format((value instanceof Date && isValid(value) ? value : parse(value)), dateFormat)
      const cmp = compareAsc(parse(_value), parse(_date))
      switch (true) {
        case ['>', 'gt'].includes(comparison) && !(cmp > 0):
        case ['>=', 'gte'].includes(comparison) && !(cmp >= 0):
        case ['<', 'lt'].includes(comparison) && !(cmp < 0):
        case ['<=', 'lte'].includes(comparison) && !(cmp <= 0):
        case ['===', 'eq'].includes(comparison) && !(cmp === 0):
        case ['!==', 'ne'].includes(comparison) && !(cmp !== 0):
          return this.createError({ message: message || i18n.t('Invalid date, must be {comparison} {date}.', { comparison, date: _date }) })
          // break
        default:
          return true
      }
    }
  })
})

yup.addMethod(yup.string, 'isDateFormat', function (message, dateFormat = 'YYYY-MM-DD HH:mm:ss') {
  return this.test({
    name: 'isDateFormat',
    message: message || i18n.t('Invalid date, use format "{dateFormat}".', { dateFormat }),
    test: value => {
      return (
        ['', null, undefined].includes(value)
        || dateFormat.replace(/[a-z]/gi, '0') === value.replace(/[0-9]/g, '0') // '0000-00-00 00:00:00' === '0000-00-00 00:00:00'
      )
    }
  })
})

yup.addMethod(yup.string, 'isDateFormatOrZero', function (message, dateFormat = 'YYYY-MM-DD HH:mm:ss') {
  return this.test({
    name: 'isDateFormatOrZero',
    message: message || i18n.t('Invalid date, use format "{dateFormat}".', { dateFormat }),
    test: value => {
      return (
        ['', null, undefined].includes(value)
        || [0, '0'].includes(value)
        || dateFormat.replace(/[a-z]/gi, '0') === value.replace(/[0-9]/g, '0') // '0000-00-00 00:00:00' === '0000-00-00 00:00:00'
      )
    }
  })
})

yup.addMethod(yup.string, 'isDomain', function (message) {
  return this.test({
    name: 'isDomain',
    message: message || i18n.t('Invalid domain name.'),
    test: value => {
      return (
        ['', null, undefined].includes(value)
        || reDomain(value)
      )
    }
  })
})

yup.addMethod(yup.string, 'isEmailCsv', function (message) {
  return this.test({
    name: 'isEmailCsv',
    message: message || i18n.t('Invalid comma-separated list of email addresses.'),
    test: value => {
      if (['', null, undefined].includes(value))
        return true
      const emails = value.split(',')
      for (let e = 0; e < emails.length; e++) {
        if (!['', null, undefined].includes(emails[e].trim()) && !reEmail(emails[e].trim()))
          return false
      }
      return true
    }
  })
})

yup.addMethod(yup.string, 'isFilename', function (message) {
  return this.test({
    name: 'isFilename',
    message: message || i18n.t('Invalid character, only letters (A-Z), numbers (0-9), underscores (_), or colons (:).'),
    test: value => ['', null, undefined].includes(value) || reFilename(value)
  })
})

yup.addMethod(yup.string, 'isFilenameWithExtension', function (extensions, message) {
  return this.test({
    name: 'isFilenameWithExtension',
    message: message || i18n.t('Invalid extension. Must be one of: {extensions}.', { extensions: extensions.join(', ') }),
    test: value => {
      const re = RegExp('^[0-9a-z\xC0-\xff_]+[0-9a-z\xC0-\xff_\\-\\.]*\\.(' + extensions.join('|') + ')$', 'gi')
      return !value || re.test(value)
    }
  })
})

yup.addMethod(yup.string, 'isFilenameWithContentType', function (contentTypes, message) {
  return this.test({
    name: 'isFilenameWithContentType',
    message: message || i18n.t('Invalid content-type. Must be one of: {contentTypes}.', { contentTypes: contentTypes.join(', ') }),
    test: value => {
      const contentType = mime.lookup(value)
      if (!contentType)
        return false
      const [ contentTypeMs, contentTypeLs ] = contentType.split('/')
      return contentTypes.reduce((valid, allowed) => {
        if (allowed === '*/*')
          return true
        const [ allowedMs, allowedLs ] = allowed.split('/')
        if (contentTypeMs === allowedMs && (allowedLs === '*' || contentTypeLs === allowedLs))
          return true
        return valid
      }, false)
    }
  })
})

export const isFQDN = (value, allowWildCard = false) => {
  if (['', null, undefined].includes(value))
    return true
  const parts = value.split('.')
  const tld = parts.pop()
  if (!parts.length || !/^([a-z\u00a1-\uffff]{2,}|xn[a-z0-9-]{2,})$/i.test(tld)) {
    return false
  }
  for (let i = 0; i < parts.length; i++) {
    let part = parts[i]
    if (part == '*') {
      if (i == 0 && allowWildCard) {
        allowWildCard = false
        continue
      }
      else {
        return false
      }
    }
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

yup.addMethod(yup.string, 'isFQDN', function (message) {
  return this.test({
    name: 'isFQDN',
    message: message || i18n.t('Invalid FQDN.'),
    test: isFQDN
  })
})

yup.addMethod(yup.string, 'isHostname', function (message) {
  return this.test({
    name: 'isFQDN',
    message: message || i18n.t('Invalid hostname.'),
    test: value => ['', null, undefined].includes(value) || reIpv4(value) || isFQDN(value)
  })
})

yup.addMethod(yup.string, 'isIpv4', function (message) {
  return this.test({
    name: 'isIpv4',
    message: message || i18n.t('Invalid IPv4 Address.'),
    test: value => ['', null, undefined].includes(value) || reIpv4(value)
  })
})

yup.addMethod(yup.string, 'isIpv4Csv', function (message) {
  return this.test({
    name: 'isIpv4Csv',
    message: message || i18n.t('Invalid comma-separated list of IPv4 addresses.'),
    test: value => {
      if (['', null, undefined].includes(value))
        return true
      const addresses = value.split(',')
      for (let e = 0; e < addresses.length; e++) {
        if (!['', null, undefined].includes(addresses[e].trim()) && !reIpv4(addresses[e].trim()))
          return false
      }
      return true
    }
  })

})

yup.addMethod(yup.string, 'isIpv6', function (message) {
  return this.test({
    name: 'isIpv6',
    message: message || i18n.t('Invalid IPv6 Address.'),
    test: value => ['', null, undefined].includes(value) || reIpv6(value)
  })
})

yup.addMethod(yup.string, 'isMAC', function (message) {
  return this.test({
    name: 'isMAC',
    message: message || i18n.t('Invalid MAC.'),
    test: value => ['', null, undefined].includes(value) || reMac(value)
  })
})

yup.addMethod(yup.string, 'isPort', function (message) {
  return this.test({
    name: 'isPort',
    message: message || i18n.t('Invalid port.'),
    test: value => ['', null, undefined].includes(value) || (+value === parseInt(value) && +value >= 1 && +value <= 65535)
  })
})

yup.addMethod(yup.string, 'isPrice', function (message) {
  return this.test({
    name: 'isPrice',
    message: message || i18n.t('Invalid price.'),
    test: value => ['', null, undefined].includes(value) || (parseFloat(value) >= 0 && ((value || '').split('.')[1] || []).length <= 2)
  })
})

yup.addMethod(yup.string, 'isStaticRoute', function (message) {
  return this.test({
    name: 'isStaticRoute',
    message: message || i18n.t('Invalid static route.'),
    test: value => ['', null, undefined].includes(value) || reStaticRoute(value)
  })
})

yup.addMethod(yup.string, 'isVLAN', function (message) {
  return this.test({
    name: 'isVlan',
    message: message || i18n.t('Invalid VLAN.'),
    test: value => ['', null, undefined].includes(value) || (+value === parseFloat(value) && +value >= 1 && +value <= 4096)
  })
})

import {
  MysqlString,
  MysqlNumber,
  MysqlDatetime,
  MysqlEnum,
  MysqlEmail,
  MysqlMac
} from '@/globals/mysql'

yup.addMethod(yup.string, 'mysql', function(columnSchema) {
  return this.test({
    name: 'mysql',
    message: i18n.t('Unknown error.'),
    test: function (value) {
      if (['', null, undefined].includes(value))
        return true
      const { type, maxLength, min, max,
        format = 'YYYY-MM-DD HH:mm:ss',
        ['enum']: _enum = [] // reserved word
      } = columnSchema

      if ([MysqlString, MysqlDatetime, MysqlEmail].includes(type) && value.length && value.length > maxLength)
        return this.createError({ message: i18n.t('Maximum {maxLength} characters.', columnSchema) })

      switch (true) {
        case (type === MysqlDatetime):
          if (!([0, '0'].includes(value)) && format.replace(/[a-z]/gi, '0') !== value.replace(/[0-9]/g, '0'))
            return this.createError({ message: i18n.t('Invalid datetime, use format "{format}".', { format }) })
          break

        case (type === MysqlNumber):
          if (!reNumeric(value))
            return this.createError({ message: i18n.t('Must be numeric.') })
          if (+value < +min)
            return this.createError({ message: i18n.t('Minimum value of {min}.', columnSchema) })
          if (+value > +max)
            return this.createError({ message: i18n.t('Maximum value of {max}.', columnSchema) })
          break

        case (type === MysqlEnum):
          if (_enum.length && !_enum.includes(value))
            return this.createError({ message: i18n.t('Invalid value.') })
          break

        case (type === MysqlEmail):
          if (!reEmail(value))
            return this.createError({ message: i18n.t('Invalid email.') })
          break

        case (type === MysqlMac):
          if (`${value}`.toLowerCase().replace(/[^0-9a-f]/g, '').length !== 12)
            return this.createError({ message: i18n.t('Invalid MAC.') })
          break
      }
      return true
    }
  })
})

export default yup
