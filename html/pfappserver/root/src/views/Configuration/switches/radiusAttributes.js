// The RADIUS attributes of a role, one "Attribute-Name = value" per line, as read by pf::util::radius_attributes

// text => [{ type, value }]
export const parse = text => `${text || ''}`.split(/\r?\n/)
  .map(line => line.trim())
  .filter(line => line && !line.startsWith('#'))
  .map(line => {
    const i = line.indexOf('=')
    if (i < 0)
      return { type: line, value: null }
    let value = line.substring(i + 1).trim()
    if (value.length > 1 && value.startsWith('"') && value.endsWith('"'))
      value = value.substring(1, value.length - 1)
    return { type: line.substring(0, i).trim(), value }
  })

// [{ type, value }] => text
export const serialize = rows => {
  const lines = rows
    .filter(({ type }) => type)
    .map(({ type, value }) => {
      value = `${value === null || value === undefined ? '' : value}`
      // keep surrounding spaces and quotes, one pair of double quotes is removed when read
      if (value !== value.trim() || (value.startsWith('"') && value.endsWith('"')))
        value = `"${value}"`
      return `${type} = ${value}`
    })
  return (lines.length) ? lines.join('\n') : null
}
