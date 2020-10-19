import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from './BaseFormGroupToggle'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'no', label: i18n.t('No') },
      { value: 'yes', label: i18n.t('Yes') }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-toggle-no-yes',
  extends: BaseFormGroupToggle,
  props
}
