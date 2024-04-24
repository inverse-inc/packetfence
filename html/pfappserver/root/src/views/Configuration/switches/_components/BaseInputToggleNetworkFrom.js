import BaseInputToggle, { props as BaseInputToggleProps } from '@/components/new/BaseInputToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: null, label: i18n.t('Disabled') },
      { value: 'static', label: i18n.t('Static'), color: 'var(--primary)' },
      { value: 'dynamic', label: i18n.t('Dynamic (via DHCP)') , color: 'var(--success)'}
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-input-toggle-network-from',
  extends: BaseInputToggle,
  props
}
