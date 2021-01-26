import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import { revokeReasons } from '../config'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => (revokeReasons)
  }
}

export default {
  name: 'base-form-group-revoke-reason',
  extends: BaseFormGroupChosenOne,
  props
}
