import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseModule from './BaseModule'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Module')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseModule
  },
  // overload :defaultItem
  defaultItem: {
    type: String
  }
}

export default {
  name: 'base-form-group-modules',
  extends: BaseFormGroupArray,
  props
}
