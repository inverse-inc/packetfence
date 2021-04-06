import { BaseFormGroupChosenMultiple, BaseFormGroupChosenMultipleProps } from '@/components/new/'

export const props = {
  ...BaseFormGroupChosenMultipleProps,

  // overload :taggable default
  taggable: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-openid-attributes',
  extends: BaseFormGroupChosenMultiple,
  props
}
