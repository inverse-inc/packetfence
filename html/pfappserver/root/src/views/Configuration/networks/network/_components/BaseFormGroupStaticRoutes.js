import { BaseFormGroupArray, BaseFormGroupArrayProps, BaseInput } from '@/components/new'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Route')
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
  name: 'base-form-group-static-routes',
  extends: BaseFormGroupArray,
  props
}
