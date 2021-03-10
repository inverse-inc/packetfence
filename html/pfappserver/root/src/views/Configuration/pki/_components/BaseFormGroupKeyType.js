import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import { keyTypes } from '../config'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => (keyTypes)
  }
}

export default {
  name: 'base-form-group-key-type',
  extends: BaseFormGroupChosenOne,
  props
}
