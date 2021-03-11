import { BaseInputChosenOneSearchable, BaseInputChosenOneSearchableProps } from '@/components/new'

export const props = {
  ...BaseInputChosenOneSearchableProps,

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
  name: 'base-form-group-search',
  extends: BaseInputChosenOneSearchable,
  props
}
