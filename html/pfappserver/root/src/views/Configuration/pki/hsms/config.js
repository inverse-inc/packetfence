export const decomposeHsm = (item) => {
   
  const { ID, CreatedAt, DeletedAt, UpdatedAt, DB, Ctx, // strip gorm decorations
    pin, // write-only, never returned
    ...rest
  } = item
  return {
    ...((ID) ? {id: `${ID}`} : {}),
    ...rest
  }
}

export const recomposeHsm = (item) => {
  const {
    id,
    pin,
    ...rest
  } = item
  return {
    ID: +id,
    ...((pin) ? { pin } : {}), // empty: keep the current PIN
    ...rest
  }
}
