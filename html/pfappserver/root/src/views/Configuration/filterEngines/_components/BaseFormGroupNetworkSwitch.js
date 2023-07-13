import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :groupValues default
  groupValues: {
    type: String,
    default: 'options'
  },
  // overload :groupLabel default
  groupLabel: {
    type: String,
    default: 'group'
  }
}

export default {
  name: 'base-form-group-network-switch',
  extends: BaseFormGroupChosenOne,
  props
}
