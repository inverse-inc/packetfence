export const decomposeCa = (item) => {
  const { id, key_usage = null, extended_key_usage = null } = item
  return {
    ...item,
    id: `${id}`,
    key_usage: (!key_usage) ? [] : key_usage.split('|'),
    extended_key_usage: (!extended_key_usage) ? [] : extended_key_usage.split('|')
  }
}

export const recomposeCa = (item) => {
  const { id, key_usage = [], extended_key_usage = [] } = item
  return {
    ...item,
    id: +id,
    key_usage: key_usage.join('|'),
    extended_key_usage: extended_key_usage.join('|')
  }
}
