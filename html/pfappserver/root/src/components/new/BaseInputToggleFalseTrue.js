import BaseInputToggle, { props as BaseInputToggleProps } from './BaseInputToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: false, label: i18n.t('False') },
      { value: true, label: i18n.t('True'), color: 'var(--primary)' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-inputs-toggle-false-true',
  extends: BaseInputToggle,
  props
}
