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

yup.addMethod(yup.string, 'isPort', function (ref, message) {
  return this.test({
    name: 'isPort',
    message: message || i18n.t('Invalid port.'),
    test: value => ['', null, undefined].includes(value) || (~~value === parseFloat(value) && ~~value >= 1 && ~~value <= 65535)
  })
})

yup.addMethod(yup.array, 'required', function (message) {
  return this.test({
    name: 'required',
    message: message || i18n.t('${path} required.'),
    test: value => (value.length > 0)
  })
})

export default yup
