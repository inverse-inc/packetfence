export const usePropsWrapper = (object, props, isWrappable = (key, value) => value.constructor === Function) => {
  return Object.keys(object)
    .reduce((wrapped, key) => {
      const child = object[key]
      if (isWrappable(key, child)) // do wrap
        wrapped[key] = params => child({
          ...props,
          ...params // params can overload props
        })
      else // do not wrap
        wrapped[key] = child
      return wrapped
    }, {})
}