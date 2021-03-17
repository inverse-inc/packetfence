export const defaultsFromMeta = (meta = {}) => {
  let defaults = {}
  Object.keys(meta).forEach(key => {
    if ('properties' in meta[key]) { // handle dot-notation keys ('.')
      Object.keys(meta[key].properties).forEach(property => {
        if (!(key in defaults)) {
          defaults[key] = {}
        }
        // default w/ object
        defaults[key][property] = meta[key].properties[property].default
      })
    } else {
      defaults[key] = meta[key].default
    }
  })
  return defaults
}



