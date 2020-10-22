import BaseInputToggle, { props as BaseInputToggleProps } from './BaseInputToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: false, label: i18n.t('Basic Mode') },
      { value: true, label: i18n.t('Advanced Mode') }
    ])
  },
  labelLeft: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-input-toggle-advanced-mode',
  extends: BaseInputToggle,
  props
}
