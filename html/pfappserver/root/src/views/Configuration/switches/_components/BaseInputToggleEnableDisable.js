import BaseInputToggle, { props as BaseInputToggleProps } from '@/components/new/BaseInputToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'enabled', label: i18n.t('Enabled'), color: 'var(--success)' },
      { value: 'disabled', label: i18n.t('Disabled'), color: 'var(--secondary)' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-input-toggle-enable-disable',
  extends: BaseInputToggle,
  props
}