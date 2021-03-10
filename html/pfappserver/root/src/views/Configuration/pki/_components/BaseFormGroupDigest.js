import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import { digests } from '../config'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => (digests)
  }
}

export default {
  name: 'base-form-group-digest',
  extends: BaseFormGroupChosenOne,
  props
}
