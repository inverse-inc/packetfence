import { BaseFormGroupInputTest, BaseFormGroupInputTestProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupInputTestProps,

  test: {
    type: Function,
    default: value => store.dispatch('$_certificates/testLetsEncrypt', value).catch(err => {
      throw err
    })
  },
  testLabel: {
    type: String,
    default: i18n.t(`Checking Let's Encrypt...`)
  }
}

export default {
  name: 'base-form-group-lets-encrypt-common-name',
  extends: BaseFormGroupInputTest,
  props
}



