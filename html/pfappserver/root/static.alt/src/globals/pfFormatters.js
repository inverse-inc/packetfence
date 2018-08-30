import store from '@/store'

export const pfFormatters = {
  datetimeIgnoreZero: (value, key, item) => {
    return (value === '0000-00-00 00:00:00') ? '' : value
  },
  categoryId: (value, key, item) => {
    if (!value) return null
    return store.state.config.roles.filter(role => role.category_id === item.category_id).map(role => role.name)
  },
  bypassRoleId: (value, key, item) => {
    if (!value) return null
    return store.state.config.roles.filter(role => role.category_id === item.bypass_role_id).map(role => role.name)
  },
  violationIdsToDescCsv: (value, key, item) => {
    if (!value) return null
    const uVids = [...new Set(value.split(',').filter(item => item))]
    return store.getters['config/sortedViolations'].filter(violation => uVids.includes(violation.id)).map(violation => violation.desc).join(', ')
  }
}
