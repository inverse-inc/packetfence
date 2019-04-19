<template>
  <b-button type="button" :disabled="disabled || results.length === 0" :variant="variant" @click="download()">
    <icon name="file-export" class="mr-1"></icon>
    <template >
      <slot>{{ $t('Export to CSV') }}</slot>
    </template>
  </b-button>
</template>

<script>
export default {
  name: 'pfButtonExportToCsv',
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
    filename: {
      type: String,
      default: 'export.csv'
    }
  },
  computed: {
    results () {
      let results = this.$store.state[this.searchableStoreName].results
      if ('resultsFilter' in this.searchableOptions) {
        results = this.searchableOptions.resultsFilter(results)
      }
      return results
    },
    visibleColumns () {
      return this.columns.filter(column => !column.locked && column.visible)
    }
  },
  methods: {
    data () {
      let formatters = {}
      this.visibleColumns.forEach(column => {
        if (column.formatter) formatters[column.key] = column.formatter
      })
      const header = this.visibleColumns.map(column => column.label)
      let keyMap = {} // build map to sort results same as header
      Object.keys(this.results[0]).forEach(key => {
        keyMap[key] = this.visibleColumns.findIndex(column => column.key === key)
      })
      const data = this.results.map(row => {
        return Object.entries(row).sort((a, b) => {
          return keyMap[a[0]] - keyMap[b[0]]
        }).map(_row => {
          const [ key, value ] = _row
          if (key in formatters) {
            return formatters[key](value, key, row) || ''
          }
          return value || ''
        })
      })
      return [ header, ...data ]
    },
    download () {
      let csvContentArray = []
      this.data().forEach(rowArray => {
        let row = rowArray.map(col => `"${col.replace('"', '\\"')}"`).join(',')
        csvContentArray.push(row)
      })

      // window.open(encodeURI(`data:text/csv;charset=utf-8,${csvContentArray.join('\r\n')}`))

      var blob = new Blob([csvContentArray.join('\r\n')], { type: 'text/csv' })
      if(window.navigator.msSaveOrOpenBlob) {
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
