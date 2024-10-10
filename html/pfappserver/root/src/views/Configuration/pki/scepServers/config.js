export const decomposeScepServer = (item) => {
   
  const { ID, CreatedAt, DeletedAt, UpdatedAt, DB, Ctx, // strip gorm decorations
    ...rest
  } = item
  return {
    ...((ID) ? {id: `${ID}`} : {}),
    ...rest
  }
}

export const recomposeScepServer = (item) => {
  const {
    id,
    ...rest
  } = item
  return {
    ID: +id,
    ...rest
  }
}
