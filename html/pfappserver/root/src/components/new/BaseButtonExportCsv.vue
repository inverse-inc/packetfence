<template>
  <b-button type="button" :size="size" :disabled="disabled || data.length === 0" :variant="variant" @click="onDownload">
    <icon name="file-export" class="mr-2"></icon>
    <template >
      <slot>{{ $t('Export to CSV') }}</slot>
    </template>
  </b-button>
</template>

<script>

const props = {
  disabled: {
    type: Boolean
  },
  variant: {
    type: String,
    default: 'outline-primary'
  },
  columns: {
    type: Array
  },
  data: {
    type: Array
  },
  filename: {
    type: String,
    default: 'export.csv'
  },
  size: {
    type: String,
    default: 'sm'
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = (props) => {
  
  const {
    columns,
    data,
    filename
  } = toRefs(props)
  
  const visibleColumns = computed(() => columns.value.filter(column => !column.locked && column.visible))
  
  const _getContents = () => {
    let formatters = {}
    visibleColumns.value.forEach(column => {
      if (column.formatter) formatters[column.key] = column.formatter
    })
    const header = visibleColumns.value.map(column => column.key)
    let keyMap = {} // build map to sort data same as header
    Object.keys(data.value[0]).forEach(key => {
      const idx = header.findIndex(column => column === key)
      if (idx >= 0) keyMap[key] = idx
    })
    const body = data.value.map(row => {
      return Object.entries(row).filter(col => header.includes(col[0])).sort((a, b) => {
        return keyMap[a[0]] - keyMap[b[0]]
      }).map(_row => {
        const [ key, value ] = _row
        if (key in formatters) {
          return formatters[key](value, key, row) || ''
        }
        return value || ''
      })
    })
    return [ header, ...body ]
  }
  
  const onDownload = () => {
    let csvContentArray = []
    _getContents().forEach(rowArray => {
      let row = rowArray.map(col => `"${col.toString().replace('"', '\\"')}"`).join(',')
      csvContentArray.push(row)
    })
    // window.open(encodeURI(`data:text/csv;charset=utf-8,${csvContentArray.join('\r\n')}`)) // doesn't allow naming
    var blob = new Blob([csvContentArray.join('\r\n')], { type: 'text/csv' })
    if (window.navigator.msSaveOrOpenBlob) {
      window.navigator.msSaveBlob(blob, filename.value)
    } else {
      var elem = window.document.createElement('a')
      elem.href = window.URL.createObjectURL(blob)
      elem.download = filename.value
      document.body.appendChild(elem)
      elem.click()
      document.body.removeChild(elem)
    }
  }
  
  return {
    visibleColumns,
    onDownload
  }
}

// @vue/component
export default {
  name: 'base-button-export-csv',
  inheritAttrs: false,
  props,
  setup
}
</script>
