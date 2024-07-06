import { oses } from '@/globals/fingerbank'
import { BaseFormGroupChosenMultipleSearchable, BaseFormGroupChosenMultipleSearchableProps } from '@/components/new/'

export const props = {
  ...BaseFormGroupChosenMultipleSearchableProps,

  // overload :options default
  options: {
    type: Array,
    default: () => Object.entries(oses).map(([value, text]) => ({ text, value }))
  }
}

export default {
  name: 'base-form-group-oses',
  extends: BaseFormGroupChosenMultipleSearchable,
  props
}
