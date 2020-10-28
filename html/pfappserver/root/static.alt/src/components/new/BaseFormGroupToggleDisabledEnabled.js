import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from './BaseFormGroupToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'disabled', label: i18n.t('Disabled') },
      { value: 'enabled', label: i18n.t('Enabled'), color: 'var(--primary)' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-toggle-disabled-enabled',
  extends: BaseFormGroupToggle,
  props
}
