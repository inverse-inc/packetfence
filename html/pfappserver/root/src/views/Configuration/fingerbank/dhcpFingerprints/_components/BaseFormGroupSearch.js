import { BaseFormGroupChosenOneSearchable, BaseFormGroupChosenOneSearchableProps } from '@/components/new'

export const props = {
  ...BaseFormGroupChosenOneSearchableProps,

  // overload :lookup
  lookup: {
    type: Object,
    default: () => ({
      search_path: 'fingerbank/all/dhcp_fingerprints/search',
      search_op:  'starts_with',
      field_name: 'value',
      value_name: 'id'
    })
  }
}

export default {
  name: 'base-form-group-search',
  extends: BaseFormGroupChosenOneSearchable,
  props
}
