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
  }
}

export default {
  name: 'base-form-group-authentication-rules',
  extends: BaseFormGroupRules,
  props
}
