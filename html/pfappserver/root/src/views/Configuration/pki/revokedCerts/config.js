export const decomposeRevokedCert = (item) => {
  // eslint-disable-next-line no-unused-vars
  const { ID, CreatedAt, DeletedAt, UpdatedAt, DB, Ctx, // strip gorm decorations
    ...rest
  } = item
  return {
    ...((ID) ? {id: `${ID}`} : {}),
    ...rest
  }
}

export const recomposeRevokedCert = (item) => {
  const {
    id,
    ...rest
  } = item
  return {
    ID: +id,
    ...rest
  }
}
