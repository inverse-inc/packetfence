import { BaseFormGroupInputPasswordTest, BaseFormGroupInputPasswordTestProps } from '@/components/new/'
import i18n from '@/utils/locale'
import api from '@/views/Assistant/_api'

export const props = {
  ...BaseFormGroupInputPasswordTestProps,

  // validates the key against the provider without saving it
  test: {
    type: Function,
    default: (value, form) => api.testProvider({ provider: form.provider, model: form.model, api_key: value })
      .then(({ ok, detail, error } = {}) => {
        if (!ok)
          throw error
        return detail
      })
      .catch(err => {
        const { response: { data: { error } = {} } = {} } = err
        throw error || err
      })
  },
  testLabel: {
    type: String,
    default: i18n.t('Validating...')
  }
}

export default {
  name: 'base-form-group-api-key-test',
  extends: BaseFormGroupInputPasswordTest,
  props
}
