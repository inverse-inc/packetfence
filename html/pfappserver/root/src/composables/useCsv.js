export const useTableColumnsItems = (columns, items) => {
  const formatters = columns.reduce((formatters, column) => {
    if (column.formatter) {
      formatters[column.key] = column.formatter
    }
    return formatters
  }, {})
  const header = columns.reduce((header, column) => {
    if (!column.locked) {
      if (column.key in formatters)
        header.push(`$${column.key}`) // `unformatted` column
      header.push(column.key) // `formatted` column
      }
    return header
  }, [])
  const body = items.map(row => {
    return header.map(key => {
      if (key.charAt(0) === '$' && key.slice(1) in formatters) // unformatted
        return row[key.slice(1)] || ''
      const value = row[key]
      if (key in formatters)
        return formatters[key](value, key, row) || ''
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