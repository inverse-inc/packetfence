import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from './BaseFormGroupToggle'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'disabled' },
      { value: 'enabled' }
    ])
  }
}

export default {
  name: 'base-form-group-toggle-disabled-enabled',
  extends: BaseFormGroupToggle,
  props
}
