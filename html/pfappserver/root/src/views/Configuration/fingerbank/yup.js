import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const reFingerprint = value => /^(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?),)?)+(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(value)

yup.addMethod(yup.string, 'isDHCPFingerprint', function (message) {
  return this.test({
    name: 'isDHCPFingerprint',
    message: message || i18n.t('Invalid fingerprint.'),
    test: value => ['', null, undefined].includes(value) || reFingerprint(value)
  })
})

yup.addMethod(yup.string, 'isOUI', function (message, separator = ':') {
  return this.test({
    name: 'isOUI',
    message: message || i18n.t('Invalid OUI.'),
    test: value => {
      if (['', null, undefined].includes(value))
        return true
      if (separator === '') {
        return /^([0-9A-F]{6})$/i.test(value)
      } else {
        value.split(separator).forEach(segment => {
          if (!/^([0-9A-F]{2})$/i.test(segment)) return false
        })
        return true
      }
    }
  })
})

export default yup
