import store from '@/store'
import bytes from '@/utils/bytes'
import filters from '@/utils/filters'

export const pfFormatters = {
  datetimeIgnoreZero: (value, key, item) => {
    return (value === '0000-00-00 00:00:00') ? '' : value
  },
  categoryId: (value, key, item) => {
    if (!value) return null
    return store.state.config.roles.filter(role => role.category_id === item.category_id).map(role => role.name)[0]
  },
  categoryIdFromIntOrString: (value, key, item) => {
    if (!value) return null
    if (!/\d+/.test(value)) {
      return store.state.config.roles.filter(role => role.name.toLowerCase() === value.toLowerCase()).map(role => role.category_id)[0] // string
    } else {
      return value // int
    }
  },
  bypassRoleId: (value, key, item) => {
    if (!value) return null
    return store.state.config.roles.filter(role => role.category_id === item.bypass_role_id).map(role => role.name)[0]
  },
  securityEventIdsToDescCsv: (value, key, item) => {
    if (!value) return null
    const uVids = [...new Set(value.split(',').filter(item => item))]
    return store.getters['config/sortedSecurityEvents'].filter(securityEvent => uVids.includes(securityEvent.id)).map(securityEvent => securityEvent.desc).join(', ')
  },
  yesNoFromString: (value, key, item) => {
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
  genderFromString: (value, key, item) => {
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
  shortDateTime: (value, key, item) => {
    return filters.shortDateTime(parseInt(value) * 1000)
  }
}
