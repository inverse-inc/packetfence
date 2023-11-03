const splitKeys = (o, s='.') => {
  return Object.entries(o)
    .reduce((types, [ns, v]) => {
      const [t, k] = ns.split(s, 2)
      types[t] = { ...types[t], [k]: v }
      return types
    }, {})
};

module.exports = {
  splitKeys
};