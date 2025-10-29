import { BaseFormGroupArray, BaseFormGroupArrayProps, BaseInput } from '@/components/new'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Network')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseInput
  },
  // overload :defaultItem
  defaultItem: {
    type: String
  }
}

export default {
  name: 'base-form-group-networks',
  extends: BaseFormGroupArray,
  props
}
