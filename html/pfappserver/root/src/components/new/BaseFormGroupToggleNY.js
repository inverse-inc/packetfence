import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from './BaseFormGroupToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'N', label: i18n.t('No') },
      { value: 'Y', label: i18n.t('Yes'), color: 'var(--primary)' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-toggle-n-y',
  extends: BaseFormGroupToggle,
  props
}
