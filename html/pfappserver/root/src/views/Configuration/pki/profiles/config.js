// fields the API omits when zero (`omitempty`) although their database
// default is not zero: a missing key means 0, it must not fall back to
// the form defaults (eg: when cloning)
const zeroOmittedFields = {
  renewal_mail: '0',
  revoked_valid_until: '0',
  acme_eab_required: 0,
  acme_account_expiry: '0',
  acme_order_expiry: '0',
  acme_authz_expiry: '0'
}

export const decomposeProfile = (item) => {
   
  const { ID, CreatedAt, DeletedAt, UpdatedAt, DB, Ctx, // strip gorm decorations
    key_usage = null, extended_key_usage = null,
    ...rest
  } = item
  return {
    ...((ID) ? {id: `${ID}`} : {}),
    ...zeroOmittedFields,
    key_usage: (!key_usage) ? [] : key_usage.split('|'),
    extended_key_usage: (!extended_key_usage) ? [] : extended_key_usage.split('|'),
    ...rest
  }
}

export const recomposeProfile = (item) => {
  const {
    id, key_usage = [], extended_key_usage = [],
    ...rest
  } = item
  return {
    ...((id) ? {ID: +id} : {}),
    key_usage: key_usage.join('|'),
    extended_key_usage: extended_key_usage.join('|'),
    ...rest
  }
}
