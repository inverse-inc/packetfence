import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseAccessDuration from './BaseAccessDuration'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Access Duration')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseAccessDuration
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      interval: null,
      unit: null,
      base: null,
      extendedInterval: null,
      extendedUnit: null
    })
  }
}

export default {
  name: 'base-form-group-access-duration-choices',
  extends: BaseFormGroupArray,
  props
}
