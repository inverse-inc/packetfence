import { BaseFormGroupChosenMultiple, BaseFormGroupChosenMultipleProps } from '@/components/new/'
import { keyUsages } from '../config'

export const props = {
  ...BaseFormGroupChosenMultipleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => (keyUsages)
  }
}

export default {
  name: 'base-form-group-key-usage',
  extends: BaseFormGroupChosenMultiple,
  props
}
