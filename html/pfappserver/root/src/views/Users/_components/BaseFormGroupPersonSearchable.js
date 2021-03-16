import { BaseFormGroupChosenOneSearchable, BaseFormGroupChosenOneSearchableProps } from '@/components/new'
import apiCall, { baseURL } from '@/utils/api'

export const props = {
  ...BaseFormGroupChosenOneSearchableProps,

  // overload :lookup
  lookup: {
    type: Function,
    default: (value, isPid) => {
      const values = (isPid)
        ? [{ field: 'pid', op: 'equals', value }]
        : [
          { field: 'pid', op: 'contains', value },
          { field: 'firstname', op: 'contains', value },
          { field: 'lastname', op: 'contains', value },
          { field: 'email', op: 'contains', value }
        ]
      const limit = (isPid) ? 1 : 1000
      return apiCall.request({
        url: '/users/search',
        method: 'post',
        baseURL,
        data: {
          query: {
            op: 'and', values: [{
              op: 'or',
              values
            }]
          },
          fields: ['pid', 'firstname', 'lastname', 'email'],
          sort: ['pid'],
          cursor: 0,
          limit
        }
      }).then(response => {
        const { data: { items = [] } = {} } = response
        return items.map(item => {
          const { pid, email, firstname, lastname } = item
          let text = `${pid}`
          if (firstname || lastname || email) {
            text += ' ('
            if (firstname || lastname)
              text += `"${firstname} ${lastname}"` 
            if (email)
              text = `${text.trim()} <${email}>`
            text += ')'
          }
          return { value: pid, text }
        })
      })
    }
  }
}

export default {
  name: 'base-form-group-person-searchable',
  extends: BaseFormGroupChosenOneSearchable,
  props
}