import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import {
  pfFieldType,
  pfFieldTypeValues
} from '@/globals/pfField'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => (pfFieldTypeValues[pfFieldType.GENDER]())
  }
}

export default {
  name: 'base-form-group-gender',
  extends: BaseFormGroupChosenOne,
  props
}
