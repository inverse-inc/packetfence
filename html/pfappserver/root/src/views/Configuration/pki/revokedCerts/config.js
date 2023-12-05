export const decomposeRevokedCert = (item) => {
   
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
    ...((id) ? {ID: +id} : {}),
    ...rest
  }
}
