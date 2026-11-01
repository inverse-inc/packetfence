import escape from 'lodash/escape'
import i18n from '@/utils/locale'

// the RADIUS attributes a role inherits, shown while the role has none of its own
export const radiusAttributesDefault = (meta, form, role) => {
  const { [`${role}RadiusAttributes`]: { placeholder } = {} } = meta
  if (!(placeholder || []).length || (form[`${role}RadiusAttributes`] || []).length)
    return undefined
  return `${i18n.t('Default')}: ${placeholder.map(({ type, value }) => escape(`${type} = ${value}`)).join('; ')}`
}
