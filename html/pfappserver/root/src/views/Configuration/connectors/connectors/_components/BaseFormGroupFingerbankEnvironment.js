import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseFingerbankEnvironment from './BaseFingerbankEnvironment'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Environment Variable')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseFingerbankEnvironment
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      name: null,
      value: null
    })
  }
}

export default {
  name: 'base-form-group-fingerbank-environment',
  extends: BaseFormGroupArray,
  props
}
