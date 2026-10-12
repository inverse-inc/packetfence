export const decomposeCa = (item) => {
   
  const { ID, CreatedAt, DeletedAt, UpdatedAt, DB, Ctx, // strip gorm decorations
    key_usage = null, extended_key_usage = null,
    ...rest
  } = item
  return {
    ...((ID) ? {id: `${ID}`} : {}),
    key_usage: (!key_usage) ? [] : key_usage.split('|'),
    extended_key_usage: (!extended_key_usage) ? [] : extended_key_usage.split('|'),
    ...rest
  }
}

export const recomposeCa = (item) => {
  const {
    id, key_usage = [], extended_key_usage = [],
    hsm_id, hsm_key_id, // `hsm_key_id` is read-only
    ...rest
  } = item
  return {
    ...((id) ? {ID: +id} : {}),
    ...((hsm_id) ? {hsm_id: `${hsm_id}`} : {}), // omit when empty
    key_usage: key_usage.join('|'),
    extended_key_usage: extended_key_usage.join('|'),
    ...rest
  }
}
