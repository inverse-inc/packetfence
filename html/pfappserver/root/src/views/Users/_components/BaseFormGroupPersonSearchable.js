import { BaseFormGroupChosenOneSearchable, BaseFormGroupChosenOneSearchableProps } from '@/components/new'
import { lookupPersons } from '../_api/lookupPersons'

export const props = {
  ...BaseFormGroupChosenOneSearchableProps,

  // overload :lookup
  lookup: {
    type: Function,
    default: (value, isPid) => lookupPersons(value, isPid)
  }
}

export default {
  name: 'base-form-group-person-searchable',
  extends: BaseFormGroupChosenOneSearchable,
  props
}