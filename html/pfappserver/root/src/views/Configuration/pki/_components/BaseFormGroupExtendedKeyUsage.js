import { BaseFormGroupChosenMultiple, BaseFormGroupChosenMultipleProps } from '@/components/new/'
import { extendedKeyUsages } from '../config'

export const props = {
  ...BaseFormGroupChosenMultipleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => (extendedKeyUsages)
  }
}

export default {
  name: 'base-form-group-extended-key-usage',
  extends: BaseFormGroupChosenMultiple,
  props
}
