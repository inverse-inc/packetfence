import BaseFormGroupRules, { props as BaseFormGroupRulesProps } from './BaseFormGroupRules'

export const props = {
  ...BaseFormGroupRulesProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      'administration'
    ])
  }
}

export default {
  name: 'base-form-group-administration-rules',
  extends: BaseFormGroupRules,
  props
}
