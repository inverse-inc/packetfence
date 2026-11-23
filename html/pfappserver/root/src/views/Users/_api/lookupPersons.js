import apiCall, { baseURL } from '@/utils/api'

/**
 * The persons whose pid, first name, last name or email contains value (or
 * whose pid is value, with isPid), as { value: pid, text } options: the lookup
 * of BaseFormGroupPersonSearchable, also given to the UI plugins (host API).
 */
export const lookupPersons = (value, isPid, limit = (isPid) ? 1 : 1000) => {
  const values = (isPid)
    ? [{ field: 'pid', op: 'equals', value }]
    : [
      { field: 'pid', op: 'contains', value },
      { field: 'firstname', op: 'contains', value },
      { field: 'lastname', op: 'contains', value },
      { field: 'email', op: 'contains', value }
    ]
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

export default lookupPersons
