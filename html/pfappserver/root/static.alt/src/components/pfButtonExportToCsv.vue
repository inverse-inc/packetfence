<template>
  <b-button type="button" :disabled="disabled" :variant="variant" @click="download()">
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
      return this.$store.state[this.searchableStoreName].visibleColumns
    }
  },
  methods: {
    data () {
      let formatters = {}
      this.columns.filter(column => !column.locked && column.visible).forEach(column => {
        if (column.formatter) formatters[column.key] = column.formatter
      })
      const header = this.columns.filter(column => !column.locked && column.visible).map(column => column.label)
      const data = this.results.map(row => {
        return Object.entries(row).map(_row => {
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
