const mergeProps = (...collections) => {
  return collections.reduce((props, collection) => {
    Object.keys(collection).forEach(key => {
      let prop = collection[key]
      let normalized = (prop.constructor === String)
        ? { default: prop }
        : prop
      if (key in props)
        props[key] = { ...props[key], ...normalized }
      else
        props[key] = normalized
    })
    return props
  }, {})
}

export {
  mergeProps
}
