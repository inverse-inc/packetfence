import { BaseFormGroupInputTest, BaseFormGroupInputTestProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupInputTestProps,

  test: {
    type: Function,
    default: (value, form) => store.dispatch('$_bases/testSmtp', form).catch(err => {
      const { response: { data: { message } = {} } = {} } = err
      throw message || err
    })
  },
  testLabel: {
    type: String,
    default: i18n.t(`Checking SMTP...`)
  }
}

export default {
  name: 'base-form-test-smtp',
  extends: BaseFormGroupInputTest,
  props
}




