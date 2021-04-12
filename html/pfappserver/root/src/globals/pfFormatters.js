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
    if (acl.$can('read', 'nodes')) {
      store.dispatch('config/getRoles')
      if (store.state.config.roles) {
        return store.state.config.roles.filter(role => role.category_id.toString() === item.category_id.toString()).map(role => role.name)[0]
      }
    } else {
      return item.category_id
    }
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
    if (acl.$can('read', 'nodes')) {
      store.dispatch('config/getRoles')
      if (store.state.config.roles) {
        return store.state.config.roles.filter(role => role.category_id === item.bypass_role_id).map(role => role.name)[0]
      }
    } else {
      return item.bypass_role_id
    }
  },
  securityEventIdToDesc: (value) => {
    if (!value) return null
    store.dispatch('config/getSecurityEvents')
    return store.getters['config/sortedSecurityEvents'].filter(securityEvent => securityEvent.id === value).map(securityEvent => securityEvent.desc)[0]
  },
  securityEventIdsToDescCsv: (value) => {
    if (!value) return null
    store.dispatch('config/getSecurityEvents')
    const uVids = [...new Set(value.split(',').filter(item => item))]
    return store.getters['config/sortedSecurityEvents'].filter(securityEvent => uVids.includes(securityEvent.id)).map(securityEvent => securityEvent.desc).join(', ')
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
