<template>
  <b-button type="button" size="sm" :disabled="disabled || data.length === 0" :variant="variant" @click="download()">
    <icon name="file-export" class="mr-1"></icon>
    <template >
      <slot>{{ $t('Export to CSV') }}</slot>
    </template>
  </b-button>
</template>

<script>
export default {
  name: 'pf-button-export-to-csv',
  props: {
    disabled: {
      type: Boolean,
      default: false
    },
    variant: {
      type: String,
      default: 'outline-primary'
    },
    searchableStoreName: {
      type: String,
      required: true
    },
    searchableOptions: {
      type: Object,
      required: true
    },
    columns: {
      type: Array,
      required: true
    },
    data: {
      type: Array,
      default: () => []
    },
    filename: {
      type: String,
      default: 'export.csv'
    }
  },
  computed: {
    visibleColumns () {
      return this.columns.filter(column => !column.locked && column.visible)
    }
  },
  methods: {
    contents () {
      let formatters = {}
      this.visibleColumns.forEach(column => {
        if (column.formatter) formatters[column.key] = column.formatter
      })
      const header = this.visibleColumns.map(column => column.label)
      let keyMap = {} // build map to sort data same as header
      Object.keys(this.data[0]).forEach(key => {
        const idx = header.findIndex(column => column === key)
        if (idx >= 0) keyMap[key] = idx
      })
      const body = this.data.map(row => {
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
    },
    download () {
      let csvContentArray = []
      this.contents().forEach(rowArray => {
        let row = rowArray.map(col => `"${col.replace('"', '\\"')}"`).join(',')
        csvContentArray.push(row)
      })
      // window.open(encodeURI(`data:text/csv;charset=utf-8,${csvContentArray.join('\r\n')}`)) // doesn't allow naming
      var blob = new Blob([csvContentArray.join('\r\n')], { type: 'text/csv' })
      if (window.navigator.msSaveOrOpenBlob) {
        window.navigator.msSaveBlob(blob, this.filename)
      } else {
        var elem = window.document.createElement('a')
        elem.href = window.URL.createObjectURL(blob)
        elem.download = this.filename
        document.body.appendChild(elem)
        elem.click()
        document.body.removeChild(elem)
      }
    }
  }
}
</script>
