export const decomposeProfile = (item) => {
  const { id, key_usage = null, extended_key_usage = null } = item
  const { DB, ...stripped } = item // remove excess `DB` column
  return {
    ...stripped,
    id: `${id}`,
    key_usage: (!key_usage) ? [] : key_usage.split('|'),
    extended_key_usage: (!extended_key_usage) ? [] : extended_key_usage.split('|')
  }
}

export const recomposeProfile = (item) => {
  const { id, key_usage = [], extended_key_usage = [] } = item
  return {
    ...item,
    id: +id,
    key_usage: key_usage.join('|'),
    extended_key_usage: extended_key_usage.join('|')
  }
}
