export const useTableColumnsItems = (columns, items) => {
  const formatters = columns.reduce((formatters, column) => {
    return (column.formatter)
      ? { ...formatters, [column.key]: column.formatter }
      : formatters
  }, {})
  const header = columns
    .filter(column => !column.locked) // omit `selected` and `buttons`
    .map(column => column.key)
  let keyMap = {} // build map to sort data same as header
  Object.keys(items[0]).forEach(key => {
    const idx = header.findIndex(column => column === key)
    if (idx >= 0)
      keyMap[key] = idx
  })
  const body = items.map(row => {
    return Object.entries(row)
      .filter(col => header.includes(col[0])).sort((a, b) => {
        return keyMap[a[0]] - keyMap[b[0]]
      })
      .map(_row => {
        const [ key, value ] = _row
        if (key in formatters) {
          return formatters[key](value, key, row) || ''
        }
        return value || ''
      })
  })
  let csvContentArray = []
  const rows = [ header, ...body ]
  rows.forEach(row => {
    let csvRow = row.map(col => `"${col.toString().replace('"', '\\"')}"`).join(',')
    csvContentArray.push(csvRow)
  })
  return csvContentArray.join('\r\n')
}