import { BaseFormGroupToggle, BaseFormGroupToggleProps } from '@/components/new'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 0, label: i18n.t('Off') },
      { value: 1, label: i18n.t('On'), color: 'var(--primary)' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-toggle-zero-one-integer-as-off-on',
  extends: BaseFormGroupToggle,
  props
}
