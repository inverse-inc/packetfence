import BaseInput, { props as BaseInputProps } from './BaseInput'

export const props = {
  ...BaseInputProps,

  // overload :type default
  type: {
    type: String,
    default: 'number'
  }
}

// @vue/component
export default {
  name: 'base-input-number',
  extends: BaseInput,
  props
}
