import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseParam from './BaseParam'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Parameter')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseParam
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      type: undefined,
      value: undefined
    })
  }
}

export default {
  name: 'base-form-group-params',
  extends: BaseFormGroupArray,
  props
}
