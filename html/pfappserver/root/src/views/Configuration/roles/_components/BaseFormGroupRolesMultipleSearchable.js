import { BaseFormGroupChosenMultipleSearchable, BaseFormGroupChosenMultipleSearchableProps } from '@/components/new/'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupChosenMultipleSearchableProps,

  // overload :lookup — Object-based (standard pattern)
  lookup: {
    type: Object,
    default: () => ({
      search_path: 'config/roles/search',
      field_name: 'id',
      value_name: 'id'
    })
  },

  // overload :options — prime dropdown with first 100 results via GET
  options: {
    type: Promise,
    default: () => {
      return apiCall.get('config/roles', { params: { limit: 100, sort: 'id' } })
        .then(response => {
          const { data: { items = [] } = {} } = response
          return items.map(item => ({
            value: item.id,
            text: item.notes ? `${item.id} - ${item.notes}` : item.id
          }))
        })
    }
  }
}

export default {
  name: 'base-form-group-roles-multiple-searchable',
  extends: BaseFormGroupChosenMultipleSearchable,
  props
}
