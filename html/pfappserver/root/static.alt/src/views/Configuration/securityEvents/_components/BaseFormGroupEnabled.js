import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from '@/components/new/BaseFormGroupToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'N', label: i18n.t('No'), color: 'var(--danger)' },
      { value: 'Y', label: i18n.t('Yes'), color: 'var(--success)' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-enabled',
  extends: BaseFormGroupToggle,
  props
}
