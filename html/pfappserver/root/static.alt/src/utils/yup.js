import * as yup from 'yup'
import i18n from '@/utils/locale'

yup.setLocale({ // default validators
  mixed: {
    required: args => args.message || i18n.t('{path} required.', args)
  },
  string: {
    email: args => args.message || i18n.t('Invalid Email.'),
    min: args => args.message || i18n.t('Minimum {min} characters.', args),
    max: args => args.message || i18n.t('Maximum {max} characters.', args)
  }
})

yup.addMethod(yup.string, 'in', function (ref, message) {
  return this.test({
    name: 'in',
    message: message || i18n.t('Invalid value'),
    test: value => {
      return ref.includes(value)
    }
  })
})

yup.addMethod(yup.string, 'maxAsInt', function (ref, message) {
  return this.test({
    name: 'maxAsInt',
    message: message || i18n.t('Maximum {maxValue}.', { maxValue: ref }),
    test: value => (+value <= +ref)
  })
})

yup.addMethod(yup.string, 'minAsInt', function (ref, message) {
  return this.test({
    name: 'minAsInt',
    message: message || i18n.t('Minimum {minValue}.', { minValue: ref }),
    test: value => (+value >= +ref)
  })
})

yup.addMethod(yup.array, 'required', function (message) {
  return this.test({
    name: 'required',
    message: message || i18n.t('${path} required.'),
    test: value => (value.length > 0)
  })
})


const reCommonName = value => /^([A-Z]+|[A-Z]+[0-9A-Z_:]*[0-9A-Z]+)$/i.test(value)
const reIpv4 = value => /^(([0-9]{1,3}.){3,3}[0-9]{1,3})$/i.test(value)
const reIpv6 = value => /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/i.test(value)
const reFilename = value => /^[^\\/?%*:|"<>]+$/.test(value)

yup.addMethod(yup.string, 'isCIDR', function (message) {
  return this.test({
    name: 'isCIDR',
    message: message || i18n.t('Invalid CIDR.'),
    test: value => {
      if (['', null, undefined].includes(value))
        return true
      const [ ipv4, network, ...extra ] = value.split('/')
      return (
        extra.length === 0 &&
        +network > 0 && +network < 31 &&
        reIpv4(ipv4)
      )
    }
  })
})

yup.addMethod(yup.string, 'isCommonName', function (message) {
  return this.test({
    name: 'isCommonName',
    message: message || i18n.t('Invalid character, only letters (A-Z), numbers (0-9), underscores (_), or colons (:).'),
    test: value => ['', null, undefined].includes(value) || reCommonName(value)
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
      const re = RegExp('^[a-zA-Z0-9_]+[a-zA-Z0-9_\\-\\.]*\\.(' + extensions.join('|') + ')$')
      return !value || re.test(value)
    }
  })
})

yup.addMethod(yup.string, 'isFQDN', function (message) {
  return this.test({
    name: 'isFQDN',
    message: message || i18n.t('Invalid FQDN.'),
    test: value => {
      if (['', null, undefined].includes(value))
        return true
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
  })
})

yup.addMethod(yup.string, 'isIpv4', function (message) {
  return this.test({
    name: 'isIpv4',
    message: message || i18n.t('Invalid IPv4 Address.'),
    test: value => ['', null, undefined].includes(value) || reIpv4(value)
  })
})

yup.addMethod(yup.string, 'isIpv6', function (message) {
  return this.test({
    name: 'isIpv6',
    message: message || i18n.t('Invalid IPv6 Address.'),
    test: value => ['', null, undefined].includes(value) || reIpv6(value)
  })
})

yup.addMethod(yup.string, 'isPort', function (message) {
  return this.test({
    name: 'isPort',
    message: message || i18n.t('Invalid port.'),
    test: value => ['', null, undefined].includes(value) || (+value === parseFloat(value) && +value >= 1 && +value <= 65535)
  })
})

yup.addMethod(yup.string, 'isVlan', function (message) {
  return this.test({
    name: 'isVlan',
    message: message || i18n.t('Invalid VLAN.'),
    test: value => ['', null, undefined].includes(value) || (+value === parseFloat(value) && +value >= 1 && +value <= 4096)
  })
})

export default yup
