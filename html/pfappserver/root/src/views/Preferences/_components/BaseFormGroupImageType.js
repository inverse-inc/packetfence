import {
  BaseFormGroupChosenOne,
  BaseFormGroupChosenOneProps
}  from '@/components/new/'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ['png', 'svg', 'jpeg', 'webp'].map(type => ({ value: type, text: type.toUpperCase() }))
  }
}

export default {
  name: 'base-form-group-image-type',
  extends: BaseFormGroupChosenOne,
  props
}
