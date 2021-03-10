import { BaseInputToggle, BaseInputToggleProps } from '@/components/new/'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: false, label: i18n.t('Register') },
      { value: true, label: i18n.t('Register'), color: 'var(--primary)' }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-input-toggle-autoreg',
  extends: BaseInputToggle,
  props
}
