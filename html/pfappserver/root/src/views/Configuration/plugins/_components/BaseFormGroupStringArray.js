import { BaseFormGroupArray, BaseFormGroupArrayProps, BaseInput } from '@/components/new'

export const props = {
  ...BaseFormGroupArrayProps,

  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseInput
  },
  // overload :defaultItem
  defaultItem: {
    type: String,
    default: ''
  }
}

export default {
  name: 'base-form-group-string-array',
  extends: BaseFormGroupArray,
  props
}
