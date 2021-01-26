import BaseInput, { props as BaseInputProps } from './BaseInput'

export const props = {
  ...BaseInputProps,

  // overload :type default
  type: {
    type: String,
    default: 'password'
  }
}

// @vue/component
export default {
  name: 'base-input-password',
  extends: BaseInput,
  props
}
