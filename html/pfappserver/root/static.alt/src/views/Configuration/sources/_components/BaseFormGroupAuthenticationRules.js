import BaseFormGroupRules, { props as BaseFormGroupRulesProps } from './BaseFormGroupRules'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupRulesProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      'authentication'
    ])
  },
  invalidFeedback: {
    type: String,
    default: i18n.t('Authentication Rules contains error(s).')
  }
}

export default {
  name: 'base-form-group-authentication-rules',
  extends: BaseFormGroupRules,
  props
}
