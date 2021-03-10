import { BaseInputChosenOne, BaseInputChosenOneProps } from '@/components/new/'

export const props = {
  ...BaseInputChosenOneProps,

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
  name: 'base-module',
  extends: BaseInputChosenOne,
  props
}
