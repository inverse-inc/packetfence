import BaseFormGroupInput, { props as BaseFormGroupInputProps } from './BaseFormGroupInput'

export const props = {
  ...BaseFormGroupInputProps,

  // overload :type default
  type: {
    type: String,
    default: 'number'
  }
}

// @vue/component
export default {
  name: 'base-form-group-input-number',
  extends: BaseFormGroupInput,
  props
}
