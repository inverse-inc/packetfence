import { BaseFormGroupToggle, BaseFormGroupToggleProps } from '@/components/new/'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'disabled', label: i18n.t('Disabled'), color: 'var(--danger)', icon: 'times' },
      { value: 'enabled', label: i18n.t('Enabled'), color: 'var(--success)', icon: 'check' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-status',
  extends: BaseFormGroupToggle,
  props
}

