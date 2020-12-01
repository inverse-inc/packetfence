import { BaseFormGroupChosenOneSearchable, BaseFormGroupChosenOneSearchableProps } from '@/components/new'

export const props = {
  ...BaseFormGroupChosenOneSearchableProps,

  // overload :lookup
  lookup: {
    type: Object,
    default: () => ({
      search_path: 'fingerbank/all/devices/search',
      field_name: 'name',
      value_name: 'id'
    })
  }
}

export default {
  name: 'base-form-group-search',
  extends: BaseFormGroupChosenOneSearchable,
  props
}
