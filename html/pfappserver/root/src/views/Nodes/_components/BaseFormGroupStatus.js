import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import {
  pfSearchConditionType,
  pfSearchConditionValues
} from '@/globals/pfSearch'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => pfSearchConditionValues[pfSearchConditionType.NODE_STATUS]
  }
}

export default {
  name: 'base-form-group-status',
  extends: BaseFormGroupChosenOne,
  props
}
