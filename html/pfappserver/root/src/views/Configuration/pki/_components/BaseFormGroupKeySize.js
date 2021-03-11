import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import { keySizes } from '../config'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => (keySizes)
  }
}

export default {
  name: 'base-form-group-key-size',
  extends: BaseFormGroupChosenOne,
  props
}
