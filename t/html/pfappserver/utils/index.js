const splitKeys = (o, s='.') => {
  return Object.entries(o)
    .reduce((types, [ns, v]) => {
      const [t, k] = ns.split(s, 2)
      types[t] = { ...types[t], [k]: v }
      return types
    }, {})
};

const flatten = (data, prefix = false, result = null) => {
  result = result || {};
  if (prefix && typeof data === 'object' && data !== null && Object.keys(data).length === 0) {
    result[prefix] = Array.isArray(data) ? [] : {};
    return result;
  }
  prefix = prefix ? prefix + '.' : ''
  for (const i in data) {
    if (Object.prototype.hasOwnProperty.call(data, i)) {
      // Only recurse on true objects and arrays, ignore custom classes like dates
      if (typeof data[i] === 'object' && (Array.isArray(data[i]) || Object.prototype.toString.call(data[i]) === '[object Object]') && data[i] !== null) {
        // Recursion on deeper objects
        flatten(data[i], prefix + i, result)
      } else {
        result[prefix + i] = data[i]
      }
    }
  }
  return result
};

module.exports = {
  splitKeys,
  flatten
};