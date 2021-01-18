export const decomposeProfile = (item) => {
  const { ID, key_usage = null, extended_key_usage = null } = item
  return {
    ...item,
    ID: `${ID}`,
    key_usage: (!key_usage) ? [] : key_usage.split('|'),
    extended_key_usage: (!extended_key_usage) ? [] : extended_key_usage.split('|')
  }
}

export const recomposeProfile = (item) => {
  const { ID, key_usage = [], extended_key_usage = [] } = item
  return {
    ...item,
    ID: +ID,
    key_usage: key_usage.join('|'),
    extended_key_usage: extended_key_usage.join('|')
  }
}
