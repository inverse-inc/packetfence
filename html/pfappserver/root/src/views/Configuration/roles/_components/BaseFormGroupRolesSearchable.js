import { BaseFormGroupChosenOneSearchable, BaseFormGroupChosenOneSearchableProps } from '@/components/new/'
import apiCall, { baseURL } from '@/utils/api'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupChosenOneSearchableProps,

  // overload :lookup — Function-based to control display format
  lookup: {
    type: Function,
    default: (value, isKeyLookup) => {
      const values = (isKeyLookup)
        ? [{ field: 'id', op: 'equals', value }]
        : [
            { field: 'id', op: 'contains', value },
            { field: 'notes', op: 'contains', value }
          ]
      const limit = (isKeyLookup) ? 1 : 100
      return apiCall.request({
        url: 'config/roles/search',
        method: 'post',
        baseURL,
        data: {
          query: {
            op: 'and',
            values: [{
              op: 'or',
              values
            }]
          },
          fields: ['id', 'notes'],
          sort: ['id'],
          cursor: 0,
          limit
        }
      }).then(response => {
        const { data: { items = [] } = {} } = response
        const roles = items.map(item => ({
          value: item.id,
          text: item.notes ? `${item.id} - ${item.notes}` : item.id
        }))
        return (isKeyLookup)
          ? roles
          : [{ value: null, text: i18n.t('No Role') }, ...roles]
      })
    }
  },

  // overload :options — prime dropdown with first 100 results via GET
  options: {
    type: Promise,
    default: () => {
      return apiCall.get('config/roles', { params: { limit: 100, sort: 'id' } })
        .then(response => {
          const { data: { items = [] } = {} } = response
          return [
            { value: null, text: i18n.t('No Role') },
            ...items.map(item => ({
              value: item.id,
              text: item.notes ? `${item.id} - ${item.notes}` : item.id
            }))
          ]
        })
    }
  }
}

export default {
  name: 'base-form-group-roles-searchable',
  extends: BaseFormGroupChosenOneSearchable,
  props
}
