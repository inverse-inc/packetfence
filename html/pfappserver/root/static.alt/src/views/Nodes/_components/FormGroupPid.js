import { BaseFormGroupChosenOneSearchable, BaseFormGroupChosenOneSearchableProps } from '@/components/new'

export const props = {
  ...BaseFormGroupChosenOneSearchableProps,

  // overload :lookup
  lookup: {
    type: Object,
    default: () => ({
      search_path: 'users/search',
      field_name: 'pid',
      value_name: 'pid'
    })
  }
}

export default {
  name: 'form-group-pid',
  extends: BaseFormGroupChosenOneSearchable,
  props
}