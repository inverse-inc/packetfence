import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from './BaseFormGroupToggle'

export const props = {
  ...BaseFormGroupToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'off' },
      { value: 'on' }
    ])
  }
}

export default {
  name: 'base-form-group-toggle-off-on',
  extends: BaseFormGroupToggle,
  props
}
