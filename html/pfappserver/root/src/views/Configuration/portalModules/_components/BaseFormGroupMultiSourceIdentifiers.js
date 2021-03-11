import { BaseFormGroupArray, BaseFormGroupArrayProps, BaseInputChosenOne } from '@/components/new'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Source')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseInputChosenOne
  },
  // overload :defaultItem
  defaultItem: {
    type: String
  }
}

export default {
  name: 'base-form-group-multi-source-identifiers',
  extends: BaseFormGroupArray,
  props
}
