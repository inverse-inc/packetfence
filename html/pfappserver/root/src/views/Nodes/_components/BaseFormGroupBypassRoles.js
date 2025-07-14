import BaseFormGroupRolesSearchable from '@/views/Configuration/roles/_components/BaseFormGroupRolesSearchable'
import apiCall, { baseURL } from '@/utils/api'
import i18n from '@/utils/locale'

export const props = {
  // inherit lookup/options from BaseFormGroupRolesSearchable,
  // override to map role id (name) to category_id for node forms
  ...BaseFormGroupRolesSearchable.props,

  lookup: {
    type: Function,
    default: (value, isKeyLookup) => {
      if (isKeyLookup) {
        // Use node_category (DB-backed) for key lookup since
        // config/roles/search (file-backed) does not have category_id
        return apiCall.request({
          url: `node_category/${value}`,
          method: 'get',
          baseURL
        }).then(response => {
          const { data: { item } = {} } = response
          if (!item) return []
          return [{
            value: item.category_id,
            text: item.notes ? `${item.name} - ${item.notes}` : item.name
          }]
        })
      }
      return apiCall.request({
        url: 'node_categories/search',
        method: 'post',
        baseURL,
        data: {
          query: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'name', op: 'contains', value },
                { field: 'notes', op: 'contains', value }
              ]
            }]
          },
          fields: ['name', 'notes', 'category_id'],
          sort: ['name'],
          cursor: 0,
          limit: 100
        }
      }).then(response => {
        const { data: { items = [] } = {} } = response
        const roles = items.map(item => ({
          value: item.category_id,
          text: item.notes ? `${item.name} - ${item.notes}` : item.name
        }))
        return [{ value: null, text: i18n.t('No Role') }, ...roles]
      })
    }
  },

  options: {
    type: Promise,
    default: () => {
      return apiCall.get('node_categories', { params: { limit: 100, sort: 'name' } })
        .then(response => {
          const { data: { items = [] } = {} } = response
          return [
            { value: null, text: i18n.t('No Role') },
            ...items.map(item => ({
              value: item.category_id,
              text: item.notes ? `${item.name} - ${item.notes}` : item.name
            }))
          ]
        })
    }
  }
}

export default {
  name: 'base-form-group-roles-optional',
  extends: BaseFormGroupRolesSearchable,
  props
}
