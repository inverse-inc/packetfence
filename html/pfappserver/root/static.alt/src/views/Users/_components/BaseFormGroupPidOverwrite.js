import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from '@/components/new/BaseFormGroupToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 0, label: i18n.t('Ignore') },
      { value: 1, label: i18n.t('Overwrite'), color: 'var(--primary)' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-pid-overwrite',
  extends: BaseFormGroupToggle,
  props
}
