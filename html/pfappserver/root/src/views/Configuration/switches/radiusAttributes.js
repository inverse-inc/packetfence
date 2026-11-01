import escape from 'lodash/escape'
import i18n from '@/utils/locale'

/**
 * The RADIUS attributes of a role are stored as lines of `Attribute-Name = value`,
 * split at the first equal sign as the RADIUS attributes of the switch templates,
 * and edited as the rows `{ type, value }` of the switch templates.
 */
const isRadiusAttributes = key => key.endsWith('RadiusAttributes')

export const radiusAttributesToRows = item => {
  const rows = { ...item }
  Object.keys(rows).filter(isRadiusAttributes).forEach(key => {
    if (typeof rows[key] === 'string') {
      rows[key] = rows[key].split('\n')
        .map(line => line.trim())
        .filter(line => line && !line.startsWith('#'))
        .map(line => line.match(/^([^=]+?)\s*=\s*(.*)$/))
        .filter(match => match)
        .map(([, type, value]) => ({ type, value }))
    }
  })
  return rows
}

export const radiusAttributesToText = item => {
  const text = { ...item }
  Object.keys(text).filter(isRadiusAttributes).forEach(key => {
    if (Array.isArray(text[key])) {
      text[key] = text[key].length
        ? text[key].map(({ type, value }) => `${type} = ${value}`).join('\n')
        : null
    }
  })
  return text
}

// the RADIUS attributes a role inherits, shown while the role has none of its own
export const radiusAttributesDefault = (meta, form, role) => {
  const { [`${role}RadiusAttributes`]: { placeholder } = {} } = meta
  if (!placeholder || (form[`${role}RadiusAttributes`] || []).length)
    return undefined
  return `${i18n.t('Default')}: ${placeholder.split('\n').map(escape).join('; ')}`
}
