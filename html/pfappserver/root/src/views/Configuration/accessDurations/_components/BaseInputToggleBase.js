import { BaseInputToggle, BaseInputToggleProps } from '@/components/new/'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: null, icon: 'times', tooltip: i18n.t('Absolute') },
      { value: 'F', icon: 'step-backward', tooltip: i18n.t('Relative to the beginning of the day'), color: 'var(--primary)' },
      { value: 'R', icon: 'step-backward', tooltip: i18n.t('Relative to the beginning of the period'), color: 'var(--success)' }
    ])
  }
}

export default {
  name: 'base-input-toggle-base',
  extends: BaseInputToggle,
  props
}
