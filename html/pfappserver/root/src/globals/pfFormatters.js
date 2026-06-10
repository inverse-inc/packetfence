import acl from '@/utils/acl'
import bytes from '@/utils/bytes'
import filters from '@/utils/filters'
import i18n from '@/utils/locale'
import store from '@/store'
import { format } from 'date-fns'

const locales = {
  en: require('date-fns/locale/en'),
  fr: require('date-fns/locale/fr')
}

// Resolves a node category_id to its role name for display in table cells.
// Reads the two reactive caches (the full `roles` list if some other view has
// bulk-loaded it, and the lazy per-id `cachedRoles`) so the cell re-renders once
// the name arrives. On a miss it triggers a coalesced, batched fetch rather than
// one request per row, and shows the raw id in the meantime.
const resolveRoleName = (categoryId) => {
  if (!acl.$can('read', 'nodes')) return categoryId
  const id = categoryId.toString()
  const { roles, cachedRoles } = store.state.config
  const match = (roles && roles.find(role => role.category_id.toString() === id)) ||
    cachedRoles.find(role => role.category_id.toString() === id)
  if (match) return match.name
  store.dispatch('config/getRoleByCategoryId', categoryId)
  return categoryId
}

export const pfFormatters = {
  noAdminRolePermission: (value) => {
    if (!value) return null
    return value
  },
  datetimeIgnoreZero: (value) => {
    return (value === '0000-00-00 00:00:00') ? '' : format(value, i18n.t('MM/DD/YYYY hh:mm A'), { locale: locales[i18n.locale] })
  },
  categoryId: (value, key, item) => {
    if (!value) return null
    return resolveRoleName(item.category_id)
  },
  categoryIdFromIntOrString: (value) => {
    if (!value) return null
    if (!/^\d+$/.test(value)) {
      if (acl.$can('read', 'nodes')) {
        store.dispatch('config/getRoles')
        return store.state.config.roles.filter(role => role.name.toLowerCase() === value.toLowerCase()).map(role => role.category_id)[0] // string
      } else {
        return value
      }
    } else {
      return value // int
    }
  },
  bypassRoleId: (value, key, item) => {
    if (!value) return null
    return resolveRoleName(item.bypass_role_id)
  },
  yesNoFromString: (value) => {
    if (value === null || value === '') return null
    switch (value.toLowerCase()) {
      case 'yes':
      case 'y':
      case '1':
      case 'true':
        return 'yes'
      case 'no':
      case 'n':
      case '0':
      case 'false':
        return 'no'
      default:
        return null
    }
  },
  genderFromString: (value) => {
    if (value === null || value === '') return null
    switch (value.toLowerCase()) {
      case 'm':
      case 'male':
      case 'man':
        return 'm'
      case 'f':
      case 'female':
      case 'woman':
        return 'f'
      case 'o':
      case 'other':
        return 'o'
      default:
        return null
    }
  },
  fileSize: (value, key, item) => {
    if (value === null || value === '' || ('type' in item && item.type === 'dir')) return null
    return bytes.toHuman(value, 2, true) + 'B'
  },
  shortDateTime: (value) => {
    return filters.shortDateTime(parseInt(value) * 1000)
  }
}
