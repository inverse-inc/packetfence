<template>
  <b-form @submit.prevent="doExport()">
    <b-card no-body>
      <b-card-header>
        <b-media>
          <template v-slot:aside>
            <icon name="file-csv" scale="3"></icon>
          </template>
          <h4>{{ file.name }}</h4>
          <p class="font-weight-light mb-0">{{ $t('Last Modified') }}: {{ file.lastModifiedDate }}</p>
          <p class="font-weight-light mb-0">{{ $t('Size') }}: {{ bytes.toHuman(file.size, 2, true) }}B</p>
        </b-media>
      </b-card-header>
      <div class="card-body">
        <b-row>
          <b-col cols="auto" class="mr-auto">
            <!-- NOP -->
          </b-col>
          <b-col cols="auto">
            <b-button class="ml-1" variant="link" v-b-modal="`parserOptions-${uuid}`">Parsing Options</b-button>
            <b-button class="ml-1" variant="outline-primary" @click="">Import</b-button>
            <b-button class="ml-1" variant="primary" @click="">Import All</b-button>
          </b-col>
        </b-row>

        <template v-if="previewColumnCount === 0">
          <div class="text-center text-muted">
            <b-container class="my-5">
              <b-row class="justify-content-md-center text-secondary">
                  <b-col cols="12" md="auto">
                    <b-media class="text-left">
                      <template v-slot:aside><icon name="file-excel" scale="2"></icon></template>
                      <h4>{{ $t('Could not parse file.') }}</h4>
                      <p v-t="'File is either invalid CSV or parsing options are incorrect.'"></p>
                    </b-media>
                  </b-col>
              </b-row>
            </b-container>
          </div>
        </template>

        <template v-else>

        <!-- preview options -->
        <b-row class="pf-csv-import-table-head">
          <b-col></b-col>
          <b-col cols="previewColumnCount">
            <b-pagination
              :value="page"
              :total-rows="pageMax * perPage"
              :per-page="perPage"
              @change="setPage($event)"
              class="mt-3"
            >
              <template v-slot:page="{ page, active }">
                <b v-if="active">{{ page }}</b>
                <i v-else>{{ page }}</i>
              </template>
            </b-pagination>
          </b-col>
        </b-row>

        <!-- table -->
        <div class="pf-csv-import-table" :class="{ 'hover': hover, 'striped': striped }">

          <!-- table head -->
          <b-row class="pf-csv-import-table-head">
            <b-col class="text-nowrap">
              {{ $t('Field Mappings') }}
              <span class="float-right text-nowrap">
                <icon v-if="perPage > 1" name="minus-circle"
                  class="mr-2 cursor-pointer" @click.native.stop.prevent="delCol()"
                  v-b-tooltip.hover.left.d300 :title="$t('Remove line from preview')"></icon>
                <icon name="plus-circle"
                  class="cursor-pointer" @click.native.stop.prevent="addCol()"
                  v-b-tooltip.hover.left.d300 :title="$t('Add line to preview')"></icon>
              </span>
            </b-col>
            <template v-for="(_, colIndex) in new Array(perPage)" :key="">
              <b-col class="text-nowrap">
                {{ $t('Line') }} #{{ (perPage * page) - perPage + colIndex + 1 }}
              </b-col>
            </template>
          </b-row>

          <!-- table body -->
          <b-row class="pf-csv-import-table-row" v-for="(_, rowIndex) in previewColumnCount" :key="rowIndex">
            <b-col class="text-nowrap">
              <pf-form-select
                v-model="importMapping[rowIndex]"
                :disabled="isLoading"
                :vuelidate="null"
                class="d-inline"
              >
                <template v-slot:first>
                  <option :value="null">-- {{ $t('Ignore field') }} --</option>
                </template>
                <optgroup :label="$t('Required fields')">
                  <option v-for="option in importMappingOptions.filter(o => o.required)" :key="option.value" :value="option.value" :disabled="option.disabled" :class="{'bg-success text-white': !option.disabled}">{{ option.text }}</option>
                </optgroup>
                <optgroup :label="$t('Optional fields')">
                  <option v-for="option in importMappingOptions.filter(o => !o.required)" :key="option.value" :value="option.value" :disabled="option.disabled" :class="{'bg-warning': !option.disabled}">{{ option.text }}</option>
                </optgroup>
              </pf-form-select>
              <icon v-if="importMapping[rowIndex]"
                :class="[ 'mx-2', `text-${rowVariant(rowIndex)}` ]" name="circle"></icon>
              <icon v-else
                class="mx-2 text-secondary" name="ban"></icon>
            </b-col>
            <template v-for="(_, colIndex) in new Array(perPage)" :key="">
              <b-col :class="(importMapping[rowIndex]) ? 'text-dark' : 'text-secondary'">{{ preview[colIndex].data[rowIndex] }}</b-col>
            </template>
          </b-row>
        </div>

        </template>


        <template class="p-3">
          <pre>{{ JSON.stringify(importMapping, null, 2) }}</pre>
          <pre>{{ JSON.stringify(staticMapping, null, 2) }}</pre>
        <template>

      </div>
    </b-card>
    <b-modal :id="`parserOptions-${uuid}`" size="lg" centered :title="$t('Parsing Options')">
      <pf-form-chosen v-model="config.encoding" :column-label="$t('Encoding')" :disabled="isLoading"
      :options="encoding.map(enc => { return { text: enc, value: enc } })"
      :text="$t('The encoding to use when opening local files.')"/>
      <pf-form-toggle v-model="config.header" :column-label="$t('Header')" :disabled="isLoading"
      :values="{checked: true, unchecked: false}" text="If enbabled, the first row of parsed data will be interpreted as field names."
      >{{ (config.header) ? $t('Yes') : $t('No') }}</pf-form-toggle>
      <pf-form-input v-model="config.delimiter" :column-label="$t('Delimiter')" placeholder="auto" :disabled="isLoading"
      :text="$t('The delimiting character. Leave blank to auto-detect from a list of most common delimiters.')"/>
      <pf-form-input v-model="config.newline" :column-label="$t('Newline')" placeholder="auto" :disabled="isLoading"
      :text="$t('The newline sequence. Leave blank to auto-detect. Must be one of \\r, \\n, or \\r\\n.')"/>
      <!--
      <pf-form-toggle v-model="config.skipEmptyLines" :column-label="$t('Skip Empty Lines')" :disabled="isLoading"
      :values="{checked: true, unchecked: false}" text="If enabled, lines that are completely empty (those which evaluate to an empty string) will be skipped."
      >{{ (config.skipEmptyLines) ? $t('Yes') : $t('No') }}</pf-form-toggle>
      -->
      <pf-form-input v-model="config.quoteChar" :column-label="$t('Quote Character')" :disabled="isLoading"
      :text="$t('The character used to quote fields. The quoting of all fields is not mandatory. Any field which is not quoted will correctly read.')"/>
      <pf-form-input v-model="config.escapeChar" :column-label="$t('Escape Character')" :disabled="isLoading"
      :text="$t('The character used to escape the quote character within a field. If not set, this option will default to the value of quoteChar, meaning that the default escaping of quote character within a quoted field is using the quote character two times.')"/>
      <!--
      <pf-form-input v-model="config.comments" :column-label="$t('Comments')" :disabled="isLoading"
      :text="$t('A string that indicates a comment (for example, \'#\' or \'//\').')"/>
      -->
      <!--
      <pf-form-input v-model="config.preview" :column-label="$t('Preview')" :disabled="isLoading"
      :text="$t('If > 0, only that many rows will be parsed.')"/>
      -->
      <template v-slot:modal-footer>
        <b-button variant="primary" @click="$bvModal.hide(`parserOptions-${uuid}`)">{{ $t('Continue') }}</b-button>
      </template>
    </b-modal>
  </b-form>
</template>

<script>
import Papa from 'papaparse'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormToggle from '@/components/pfFormToggle'
import bytes from '@/utils/bytes'
import encoding from '@/utils/encoding'

const { validationMixin } = require('vuelidate')

export default {
  name: 'pf-csv-import',
  components: {
    pfFormChosen,
    pfFormInput,
    pfFormSelect,
    pfFormToggle
  },
  mixins: [
    validationMixin
  ],
  props: {
    storeName: {
      type: String,
      default: null,
      required: true
    },
    file: {
      type: Object,
      default: null
    },
    fields: {
      type: Array,
      default: () => { return [] }
    },
    defaultStaticMapping: {
      type: Array,
      default: () => { return [] }
    },
    isLoading: {
      type: Boolean,
      default: false
    },
    hover: {
      type: Boolean,
      default: false
    },
    striped: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      // expose globals to template
      bytes: bytes, // @/utils/bytes
      encoding: encoding, // @/utils/bytes

      // Papa parse config
      config: {
        delimiter: '', // auto-detect
        newline: '', // auto-detect
        quoteChar: '"',
        escapeChar: '"',
        header: false,
        trimHeaders: true,
        dynamicTyping: false,
        preview: '',
        encoding: 'UTF-8',
        worker: false,
        comments: false,
        step: undefined,
        complete: undefined,
        error: undefined,
        download: false,
        skipEmptyLines: true,
        chunk: undefined,
        fastMode: undefined,
        beforeFirstChunk: undefined,
        withCredentials: undefined,
        transform: undefined
      },

      lines: [], // lines from this.file
      preview: [], // parsed from this.lines
      page: 1, // default page number
      pageMax: 1, // maximum page number
      perPage: 3, // lines per page

      importMapping: [],
      staticMapping: []
    }
  },
  computed: {
    uuid () { // tab scope
      const { file: { name, lastModified } = {} } = this
      return `${name}-${lastModified}`
    },
    previewColumnCount () {
      let count = 0
      for (let line of this.preview) {
        const { data } = line
        count = Math.max(count, data.length - 1)
      }
      this.importMapping = new Array(count) // dynamically resize importMapping
        .fill(null)
        .map((_, index) => (index in this.importMapping) ? this.importMapping[index] : null)
      return count
    },
    reservedMapping () {
      return [ ...this.importMapping.filter(val => val), ...this.staticMapping.map(val => val) ]
    },
    importMappingOptions () {
      return this.fields
        .map(field => {
          return { ...field, ...{ disabled: field.value && this.reservedMapping.includes(field.value) } } // disable if reserved
        })
    },
    staticMappingOptions () {
      return this.fields
        .filter(field => !field.required) // don't include required
        .map(field => {
          return { ...field, ...{ disabled: field.value && this.reservedMapping.includes(field.value) } } // disable if reserved
        })
    }
  },
  methods: {
    readLines (start, length) {
      const readLines = async (start, length) => {
        let lines = []
        let line
        for (let l = start; l < start + length; l++) {
          line = await this.$store.dispatch(`${this.file.storeName}/readLine`, l).then(line => {
            return line
          })
          lines.push(line)
        }
        return lines
      }
      return readLines(start, length)
    },
    loadPreview () {
      const parseLine = async (line) => {
        return await new Promise((resolve, reject) => {
          Papa.parse(line, {
            ...this.config,
            ...{
              header: false, // overload, header is handled locally
              complete: (result) => {
                const { data: { [0]: data } = {}, errors, meta } = result
                return resolve({ data, result, meta })
              }
            }
          })
        })
      }
      const loadPreview = async (lines) => {
        let preview = []
        for (let line of lines) {
          preview.push(await parseLine(line))
        }
        return preview
      }
      loadPreview(this.lines).then(preview => {
        this.preview = preview
      })
    },
    loadPage (page = this.page) {
      const length = this.perPage
      const start = ((page - 1) * length) + ((this.config.header) ? 1 : 0)
      this.readLines(start, length + 1).then(lines => { // lookahead (+1 line) for pagination
        this.lines = lines.filter((line, index) => {
          if (line !== undefined) {
            this.pageMax = Math.max(this.pageMax, Math.floor((start + index + length) / length))
            if (index < length) { // skip lookahead (+1 line)
              return true
            }
          }
          return false
        })
      })
    },
    setPage (page) {
      this.page = page
      this.loadPage(page)
    },
    addCol () {
      const { page, perPage} = this
      const firstLine = (page * perPage) - perPage
      this.page = (firstLine + perPage + 1) / (perPage + 1)
      this.perPage++
    },
    delCol () {
      const { page, perPage} = this
      const firstLine = (page * perPage) - perPage
      this.page = (firstLine + perPage - 1) / (perPage - 1)
      this.perPage--
    },
    rowVariant (index) {
      const { importMapping: { [index]: key } } = this
      if (key) {
        const fieldIndex = this.fields.findIndex(field => field.value === key)
        return (this.fields[fieldIndex].required) ? 'success' : 'warning'
      }
      return null
    }
  },
  watch: {
    'config.delimiter': {
      handler (a, b) {
        this.loadPreview()
      }
    },
    'config.encoding': {
      handler (a, b) {
        if (a !== b) {
          this.$store.dispatch(`${this.file.storeName}/setEncoding`, a)
          this.loadPage()
        }
      },
      immediate: true
    },
    'config.escapeChar': {
      handler (a, b) {
        this.loadPreview()
      }
    },
    'config.header': {
      handler (a, b) {
        this.loadPage()
      }
    },
    'config.quoteChar': {
      handler (a, b) {
        this.loadPreview()
      }
    },
    file: {
      handler (a, b) {
        this.setPage(1)
      },
      deep: true,
      immediate: true
    },
    lines: {
      handler (a, b) {
        this.loadPreview()
      }
    },
    perPage: {
      handler (a, b) {
        this.loadPage()
      }
    }
  }
}
</script>

<style lang="scss">
.pf-csv-import-table {
  color: #495057;
  border-spacing: 2px;
  .pf-csv-import-table-head {
    border-top: 1px solid #dee2e6;
    border-bottom: 2px solid #dee2e6;
    font-weight: bold;
    vertical-align: middle;
    & > div {
      vertical-align: bottom;
    }
  }
  .pf-csv-import-table-row {
    border-top: 1px solid #dee2e6;
    cursor: pointer;
  }
  .pf-csv-import-table-head,
  .pf-csv-import-table-row {
    border-color: #dee2e6;
    margin: 0;
    & > .col {
      align-self: center!important;
      padding: .75rem;
    }
    & > .col-1 {
      align-self: center!important;
      max-width: 50px;
      padding: .75rem;
      vertical-align: middle;
    }
  }
  &.striped {
    .pf-csv-import-table-row {
      &:nth-of-type(odd) {
        background-color: rgba(0,0,0,.05);
      }
    }
  }
  &.hover {
    .pf-csv-import-table-row {
      &:hover {
        background-color: rgba(0,0,0,.075);
        color: #495057;
      }
    }
  }
}
.cursor-pointer {
  cursor: pointer;
}
</style>
