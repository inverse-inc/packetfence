import { BaseFormGroupInputTest, BaseFormGroupInputTestProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupInputTestProps,

  test: {
    type: Function,
    default: (value, form) => store.dispatch('$_bases/testSmtp', form).then(response => {
      const { message } = response
      return message || i18n.t('Testing SMTP success')
    }).catch(err => {
      const { response: { data: { message } = {} } = {} } = err
      if (message)
        throw message.trim().replace('\n', '<br/>')
      else
        throw err
    })
  },
  testLabel: {
    type: String,
    default: i18n.t(`Testing SMTP...`)
  }
}

export default {
  name: 'base-form-test-smtp',
  extends: BaseFormGroupInputTest,
  props
}




