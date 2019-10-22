<template>
  <b-form @submit.prevent="doExport()">
    <b-card no-body>
      <b-card-header>
        <b-row align-v="center">
          <b-col cols="auto">
            <b-media>
              <template v-slot:aside>
                <icon name="file-csv" scale="3"></icon>
              </template>
              <h4>{{ file.name }}</h4>
              <p class="font-weight-light mb-0">{{ $t('Last Modified') }}: {{ file.lastModifiedDate }}</p>
              <p class="font-weight-light mb-0">{{ $t('Size') }}: {{ bytes.toHuman(file.size, 2, true) }}B</p>
            </b-media>
          </b-col>
          <b-col cols="auto" class="ml-auto">
            <b-button variant="outline-primary" :disabled="isDisabled" v-b-modal="`parserOptions-${uuid}`">Parsing Options</b-button>
          </b-col>
        </b-row>
      </b-card-header>
      <div class="card-body">
        <template v-if="page === 1 && previewColumnCount === 0">
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
          <b-row align-v="center">
            <b-col cols="auto">
              <h4 v-t="'Import Mappings'"></h4>
              <p v-t="'Map the required fields and any optional static fields.'"></p>
            </b-col>
            <b-col cols="auto" class="ml-auto">
              <b-pagination
                :value="page"
                :total-rows="pageMax * perPage"
                :per-page="perPage"
                :disabled="isDisabled"
                @change="setPage($event)"
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
              </b-col>
              <template v-for="(_, colIndex) in new Array(perPage)" :key="">
                <b-col class="text-nowrap">
                  <template v-if="((perPage * page) - perPage + colIndex + 1) <= (linesCount - ((config.header) ? 1 : 0))">
                    {{ $t('Line') }} #{{ (perPage * page) - perPage + colIndex + 1 }}
                  </template>
                  <template v-else>
                    <icon name="ban" class="text-secondary"/>
                  </template>
                </b-col>
              </template>
            </b-row>
            <!-- table body -->
            <b-row class="pf-csv-import-table-row" v-for="(_, rowIndex) in previewColumnCount" :key="rowIndex">
              <b-col>
                <b-form-group
                  :state="($v.importMapping.$anyError) ? false : null"
                  :invalid-feedback="getImportMappingVuelidateFeedback()"
                  class="my-1 pf-csv-import-form-group"
                >
                  <b-input-group>
                    <template v-slot:append v-if="rowVariant(rowIndex)">
                      <b-button variant="light" class="pb-1" :class="`text-${rowVariant(rowIndex)}`" :disabled="isDisabled" @click="deleteImportMapping(rowIndex)">
                        <icon name="times-circle"/>
                      </b-button>
                    </template>
                    <b-form-select
                      v-model="importMapping[rowIndex]"
                      :disabled="isDisabled"
                    >
                      <template v-slot:first>
                        <optgroup :label="$t('Ignored fields')">
                          <option :value="null" class="bg-danger text-white">{{ $t('Ignore') }}</option>
                        </optgroup>
                      </template>
                      <optgroup :label="$t('Required fields')">
                        <option v-for="option in importMappingOptions.filter(o => o.required)" :key="option.value" :value="option.value" :disabled="option.disabled" :class="{'bg-success text-white': !option.disabled}">{{ option.text }}</option>
                      </optgroup>
                      <optgroup :label="$t('Optional fields')">
                        <option v-for="option in importMappingOptions.filter(o => !o.required)" :key="option.value" :value="option.value" :disabled="option.disabled" :class="{'bg-warning': !option.disabled}">{{ option.text }}</option>
                      </optgroup>
                    </b-form-select>
                  </b-input-group>
                </b-form-group>
              </b-col>
              <template v-for="(_, colIndex) in new Array(perPage)" :key="">
                <b-col :class="(importMapping[rowIndex]) ? 'text-black' : 'text-black-50'">
                  <template v-if="getPreviewVuelidateFeedback(colIndex, rowIndex)">
                    <!-- invalid -->
                    <icon name="exclamation-circle" class="text-danger mr-1"/> {{ getPreview(colIndex, rowIndex) }}
                    <div class="invalid-feedback d-block">
                      {{ getPreviewVuelidateFeedback(colIndex, rowIndex) }}
                    </div>
                  </template>
                  <template v-else>
                    <!-- valid -->
                    {{ getPreview(colIndex, rowIndex) }}
                  </template>
                </b-col>
              </template>
            </b-row>
            <!-- table footer -->
            <b-row class="pf-csv-import-table-row" v-for="(staticMap, index) in staticMapping" :key="index">
              <b-col>
                <b-input-group>
                  <template v-slot:append>
                    <b-button @click="deleteStaticMapping(index)" variant="light" class="text-secondary pb-1" v-b-tooltip.hover.left.d300 :title="$t('Delete static field')"><icon name="times-circle"/></b-button>
                  </template>
                  <b-form-select v-model="staticMapping[index].key" :options="staticMappingOptions" :disabled="isDisabled" @change="focusStaticMapping(staticMapping[index].key)"></b-form-select>
                </b-input-group>
              </b-col>
              <b-col>

                <!-- BEGIN SUBSTRING -->
                <pf-form-input v-if="isFieldType(substringValueType, staticMapping[index])"
                  v-model="staticMapping[index].value"
                  :ref="staticMapping[index].key"
                  :disabled="isDisabled"
                  :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                  :vuelidate="$v.staticMapping[index].value"
                ></pf-form-input>

                <!-- BEGIN DATE -->
                <pf-form-datetime v-else-if="isFieldType(dateValueType, staticMapping[index])"
                  v-model="staticMapping[index].value"
                  :ref="staticMapping[index].key"
                  :config="{format: 'YYYY-MM-DD'}"
                  :disabled="isDisabled"
                  :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                  :vuelidate="$v.staticMapping[index].value"
                ></pf-form-datetime>

                <!-- BEGIN DATETIME -->
                <pf-form-datetime v-else-if="isFieldType(datetimeValueType, staticMapping[index])"
                  v-model="staticMapping[index].value"
                  :ref="staticMapping[index].key"
                  :config="{format: 'YYYY-MM-DD HH:mm:ss'}"
                  :disabled="isDisabled"
                  :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                  :vuelidate="$v.staticMapping[index].value"
                ></pf-form-datetime>

                <!-- BEGIN PREFIXMULTIPLIER -->
                <pf-form-prefix-multiplier v-else-if="isFieldType(prefixmultiplierValueType, staticMapping[index])"
                  v-model="staticMapping[index].value"
                  :ref="staticMapping[index].key"
                  :disabled="isDisabled"
                  :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                  :vuelidate="$v.staticMapping[index].value"
                ></pf-form-prefix-multiplier>

                <!-- BEGIN YESNO -->
                <pf-form-toggle  v-else-if="isFieldType(yesnoValueType, staticMapping[index])"
                  v-model="staticMapping[index].value"
                  :ref="staticMapping[index].key"
                  :disabled="isDisabled"
                  :values="{checked: 'yes', unchecked: 'no'}"
                  :vuelidate="$v.staticMapping[index].value"
                >{{ (staticMapping[index].value === 'yes') ? $t('Yes') : $t('No') }}</pf-form-toggle>

                <!-- BEGIN GENDER -->
                <pf-form-chosen v-else-if="isFieldType(genderValueType, staticMapping[index])"
                  :value="staticMapping[index].value"
                  label="name"
                  track-by="value"
                  :ref="staticMapping[index].key"
                  :disabled="isDisabled"
                  :options="fieldTypeValues[genderValueType]()"
                  :vuelidate="$v.staticMapping[index].value"
                  @input="staticMapping[index].value = $event"
                  collapse-object
                ></pf-form-chosen>

                <!-- BEGIN NODE_STATUS -->
                <pf-form-chosen v-else-if="isFieldType(nodeStatusValueType, staticMapping[index])"
                  :value="staticMapping[index].value"
                  label="name"
                  track-by="value"
                  :ref="staticMapping[index].key"
                  :disabled="isDisabled"
                  :options="fieldTypeValues[nodeStatusValueType]()"
                  :vuelidate="$v.staticMapping[index].value"
                  @input="staticMapping[index].value = $event"
                  collapse-object
                ></pf-form-chosen>

                <!-- BEGIN ROLE -->
                <pf-form-chosen v-else-if="isFieldType(roleValueType, staticMapping[index])"
                  :value="staticMapping[index].value"
                  label="name"
                  track-by="value"
                  :ref="staticMapping[index].key"
                  :disabled="isDisabled"
                  :options="fieldTypeValues[roleValueType](context)"
                  :vuelidate="$v.staticMapping[index].value"
                  @input="staticMapping[index].value = $event"
                  collapse-object
                ></pf-form-chosen>

                <!-- BEGIN SOURCE -->
                <pf-form-chosen v-else-if="isFieldType(sourceValueType, staticMapping[index])"
                  :value="staticMapping[index].value"
                  label="name"
                  track-by="value"
                  :ref="staticMapping[index].key"
                  :disabled="isDisabled"
                  :options="fieldTypeValues[sourceValueType](context)"
                  :vuelidate="$v.staticMapping[index].value"
                  @input="staticMapping[index].value = $event"
                  collapse-object
                ></pf-form-chosen>

                <!-- BEGIN ***CATCHALL*** -->
                <pf-form-input v-else
                  v-model="staticMapping[index].value"
                  :ref="staticMapping[index].key"
                  :disabled="isDisabled"
                  :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                  :vuelidate="$v.staticMapping[index].value"
                ></pf-form-input>

              </b-col>
              <b-col v-for="(_) in new Array(perPage - 1)">-</b-col>
            </b-row>
            <b-row class="pf-csv-import-table-row" v-if="staticMappingOptions.filter(f => f.value && !f.disabled).length > 0">
              <b-col>
                <b-form-select v-model="staticMappingSelect" :options="staticMappingOptions" :disabled="isDisabled" @change="addStaticMapping()">
                  <template v-slot:first>
                    <option :value="null" disabled>-- {{ $t('Choose static field') }} --</option>
                  </template>
                </b-form-select>
              </b-col>
              <b-col v-for="(_) in new Array(perPage)"><!-- NOP --></b-col>
            </b-row>
          </div>
        </template>
      </div>
      <b-card-footer v-if="previewColumnCount > 0" @mouseenter="$v.$touch()">
        <b-row align-v="center">
          <b-col cols="auto">
            <b-button variant="primary" :disabled="isDisabled || isMappingError" @click="importAll()">
              <icon v-if="isImporting" name="circle-notch" spin class="mr-1"></icon>
              <icon v-else name="download" class="mr-1"></icon>
              {{ $t('Import') }}
            </b-button>
            <b-button variant="link" :disabled="isDisabled" v-b-modal="`importOptions-${uuid}`">Import Options</b-button>
            <span v-if="isMappingError" class="ml-2">
              <icon name="exclamation-circle" class="text-danger mr-1"/>
              <span class="invalid-feedback d-inline" v-t="'Fix all errors before importing.'"></span>
            </span>
          </b-col>
          <b-col cols="auto" class="ml-auto">
            <b-button :disabled="isDisabled || perPage === 1"
              class="pr-3 text-secondary" variant="light" size="sm" pill
              @click="deletePageColumn()"
            ><icon name="minus-circle" class="mr-1"></icon> {{ $t('Remove Line') }}</b-button>

            <b-button :disabled="isDisabled"
              class="ml-2 pr-3 text-secondary" variant="light" size="sm" pill
              @click="addPageColumn()"
            ><icon name="plus-circle" class="mr-1"></icon> {{ $t('Add Line') }}</b-button>
          </b-col>
        </b-row>
      </b-card-footer>
    </b-card>

    <b-modal :id="`parserOptions-${uuid}`" size="lg" centered :title="$t('Parsing Options')">
      <pf-form-chosen v-model="config.encoding" :column-label="$t('Encoding')" :disabled="isDisabled"
      :options="encoding.map(enc => { return { text: enc, value: enc } })"
      :text="$t('The encoding to use when opening local files.')"/>
      <pf-form-toggle v-model="config.header" :column-label="$t('Header')" :disabled="isDisabled"
      :values="{checked: true, unchecked: false}" text="If enabled, the first row of parsed data will be interpreted as field names."
      >{{ (config.header) ? $t('Yes') : $t('No') }}</pf-form-toggle>
      <pf-form-input v-model="config.delimiter" :column-label="$t('Delimiter')" placeholder="auto" :disabled="isDisabled"
      :text="$t('The delimiting character. Leave blank to auto-detect from a list of most common delimiters.')"/>
      <pf-form-input v-model="config.newline" :column-label="$t('Newline')" placeholder="auto" :disabled="isDisabled"
      :text="$t('The newline sequence. Leave blank to auto-detect. Must be one of \\r, \\n, or \\r\\n.')"/>
      <!--
      <pf-form-toggle v-model="config.skipEmptyLines" :column-label="$t('Skip Empty Lines')" :disabled="isDisabled"
      :values="{checked: true, unchecked: false}" text="If enabled, lines that are completely empty (those which evaluate to an empty string) will be skipped."
      >{{ (config.skipEmptyLines) ? $t('Yes') : $t('No') }}</pf-form-toggle>
      -->
      <pf-form-input v-model="config.quoteChar" :column-label="$t('Quote Character')" :disabled="isDisabled"
      :text="$t('The character used to quote fields. The quoting of all fields is not mandatory. Any field which is not quoted will correctly read.')"/>
      <pf-form-input v-model="config.escapeChar" :column-label="$t('Escape Character')" :disabled="isDisabled"
      :text="$t('The character used to escape the quote character within a field. If not set, this option will default to the value of quoteChar, meaning that the default escaping of quote character within a quoted field is using the quote character two times.')"/>
      <!--
      <pf-form-input v-model="config.comments" :column-label="$t('Comments')" :disabled="isDisabled"
      :text="$t('A string that indicates a comment (for example, \'#\' or \'//\').')"/>
      -->
      <!--
      <pf-form-input v-model="config.preview" :column-label="$t('Preview')" :disabled="isDisabled"
      :text="$t('If > 0, only that many rows will be parsed.')"/>
      -->
      <template v-slot:modal-footer>
        <b-button variant="primary" @click="$bvModal.hide(`parserOptions-${uuid}`)">{{ $t('Continue') }}</b-button>
      </template>
    </b-modal>

    <b-modal :id="`importOptions-${uuid}`" size="lg" centered :title="$t('Import Options')">
      <pf-form-toggle v-model="config.ignoreInsertIfNotExists" :column-label="$t('Insert new')" :disabled="isDisabled"
      :values="{checked: false, unchecked: true}" text="If enabled, items that do not currently exist are created."
      >{{ (config.ignoreInsertIfNotExists) ? $t('No') : $t('Yes') }}</pf-form-toggle>
      <pf-form-toggle v-model="config.ignoreUpdateIfExists" :column-label="$t('Update exists')" :disabled="isDisabled"
      :values="{checked: false, unchecked: true}" text="If enabled, items that currently exist are overwritten."
      >{{ (config.ignoreUpdateIfExists) ? $t('No') : $t('Yes') }}</pf-form-toggle>
      <pf-form-chosen v-model="config.chunkSize" :column-label="$t('API chunk size')" :disabled="isDisabled"
      :options="[10, 50, 100, 500, 1000].map(i => { return { value: i, text: i } })"
      :text="$t('The number of items imported with each API request. Higher numbers are faster but consume more memory with large files.')"/>
      <template v-slot:modal-footer>
        <b-button variant="primary" @click="$bvModal.hide(`importOptions-${uuid}`)">{{ $t('Continue') }}</b-button>
      </template>
    </b-modal>

    <b-modal :id="`importProgress-${uuid}`" size="lg" :title="$t('Import Progress')"
      centered scrollable hide-header-close no-close-on-backdrop no-close-on-esc no-stacking
    >
      <h4>Hello World</h4>
      <template v-slot:modal-footer>
        <b-button variant="primary" @click="$bvModal.hide(`importProgress-${uuid}`)">{{ $t('Continue') }}</b-button>
      </template>
    </b-modal>

  </b-form>
</template>

<script>
import Papa from 'papaparse'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormToggle from '@/components/pfFormToggle'

import {
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import {
  conditional
} from '@/globals/pfValidators'

import bytes from '@/utils/bytes'
import encoding from '@/utils/encoding'

import {
  required
} from 'vuelidate/lib/validators'

const { validationMixin } = require('vuelidate')

export default {
  name: 'pf-csv-import',
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormPrefixMultiplier,
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
    hover: {
      type: Boolean,
      default: false
    },
    striped: {
      type: Boolean,
      default: false
    },
    isLoading: {
      type: Boolean,
      default: false
    },
    importFunction: {
      type: Function,
      default: () => {}
    }
  },
  data () {
    return {
      // expose globals
      bytes: bytes, // @/utils/bytes
      encoding: encoding, // @/utils/bytes
      fieldTypeValues: fieldTypeValues, // @/globals/pfField
      context: this,

      substringValueType:        fieldType.SUBSTRING,
      dateValueType:             fieldType.DATE,
      datetimeValueType:         fieldType.DATETIME,
      prefixmultiplierValueType: fieldType.PREFIXMULTIPLIER,
      genderValueType:           fieldType.GENDER,
      nodeStatusValueType:       fieldType.NODE_STATUS,
      roleValueType:             fieldType.ROLE,
      sourceValueType:           fieldType.SOURCE,
      yesnoValueType:            fieldType.YESNO,

      config: {
        // Papa parse config
        delimiter: '', // auto-detect
        newline: '', // auto-detect
        quoteChar: '"',
        escapeChar: '"',
        header: true,
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
        transform: undefined,

        // Import config
        chunkSize: 100,
        stopOnFirstError: true,
        ignoreUpdateIfExists: false,
        ignoreInsertIfNotExists: false
      },

      lines: [], // lines from this.file
      linesCount: 0, // maximum number of lines from this.lines
      preview: [], // parsed from this.lines
      previewColumnCount: 0, // maximum number of columns from this.preview
      page: 1, // current page number
      perPage: 3, // lines per page

      importMapping: [], // user selection(s) for existing import mappings
      staticMapping: [], // user selection(s) for existing static mappings
      staticMappingSelect: null,

      isImporting: false,
      importErrors: [],
      importModel: []
    }
  },
  computed: {
    uuid () { // tab scope
      const { file: { name, lastModified } = {} } = this
      return `${name}-${lastModified}`
    },
    pageMax () {
      const { perPage, linesCount, config: { header } = {} } = this
      return Math.ceil((linesCount - ((header) ? 1 : 0)) / perPage)
    },
    reservedMapping () {
      return [ ...this.importMapping.filter(field => field), ...this.staticMapping.map(field => field.key) ]
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
    },
    rowVariant () {
      return (index) => {
        const { importMapping: { [index]: key } } = this
        if (key) {
          const fieldIndex = this.fields.findIndex(field => field.value === key)
          return (this.fields[fieldIndex].required) ? 'success' : 'warning'
        }
        return null
      }
    },
    isDisabled () {
      const { isLoading, isImporting } = this
      return (isLoading || isImporting)
    },
    isMappingError () {
      const {
        $v: {
          importMapping: { $anyError: importMappingError = false } = {},
          staticMapping: { $anyError: staticMappingError = false } = {},
          preview: { $anyError: previewError = false } = {}
        } = {}
      } = this
      return importMappingError || staticMappingError || previewError
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
                if (data) {
                  this.previewColumnCount = Math.max(this.previewColumnCount, data.length - 1)
                }
                return resolve({ data, errors, meta })
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
      const offset = ((this.config.header) ? 1 : 0)
      const start = ((page - 1) * length) + offset
      this.readLines(start, length + 1).then(lines => { // lookahead (+1 line) for pagination
        this.lines = lines.filter((line, index) => {
          if (line !== undefined) { // !EOF
            this.linesCount = Math.max(this.linesCount, start + index + 1)
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
    addPageColumn () {
      const { page, perPage} = this
      const firstLine = (page * perPage) - perPage
      this.page = (firstLine + perPage + 1) / (perPage + 1)
      this.perPage++
    },
    deletePageColumn () {
      const { page, perPage} = this
      const firstLine = (page * perPage) - perPage
      this.page = (firstLine + perPage - 1) / (perPage - 1)
      this.perPage--
    },
    addStaticMapping () {
      const key = this.staticMappingSelect
      if (this.reservedMapping.includes(key)) return
      this.staticMapping.push({ key, value: null })
      this.focusStaticMapping(key)
      this.staticMappingSelect = null
    },
    focusStaticMapping (key) {
      this.$nextTick(() => {
        const { $refs: { [key]: { [0]: { focus } = {} } = {} } = {} } = this
        if (focus) {
          focus()
        }
      })
    },
    deleteStaticMapping (index) {
      this.staticMapping.splice(index, 1)
    },
    deleteImportMapping (index) {
      this.$set(this.importMapping, index, null)
    },
    isFieldType (type, input) {
      if (!input.key) return false
      const index = this.fields.findIndex(field => input.key === field.value)
      if (index >= 0) {
        const field = this.fields[index]
        if ('types' in field && field.types.includes(type)) {
          return true
        }
      }
      return false
    },
    getImportMappingVuelidateFeedback () {
      let feedback = []
      const { $v: { importMapping: vuelidate = {} } = {} } = this
      if (vuelidate.$invalid) {
        Object.keys(vuelidate).forEach((key) => {
          if (key[0] !== '$' && vuelidate[key] === false) {
            feedback.push(key)
          }
        })
      }
      return feedback.join(' ').trim() || null
    },
    getPreview (colIndex, rowIndex) {
      const { preview: { [colIndex]: { data: { [rowIndex]: preview = null } = {} } = {} } = {} } = this
      return preview
    },
    getPreviewVuelidateFeedback (colIndex, rowIndex) {
      let feedback = []
      if (this.importMapping[rowIndex]) {
        const { $v: { preview: { $each: { [colIndex]: { data: { [rowIndex]: vuelidate = {} } = {} } = {} } = {} } = {} } = {} } = this
        if (vuelidate.$invalid) {
          Object.keys(vuelidate).forEach((key) => {
            if (key[0] !== '$' && vuelidate[key] === false) {
              feedback.push(key)
            }
          })
        }
      }
      return feedback.join(' ').trim() || null
    },
    importAll () {

      this.isImporting = true
      this.$bvModal.show(`importProgress-${this.uuid}`)

      const parseLines = async (start, length) => {
        return new Promise((resolve, reject) => {
          this.readLines(start, length).then(async (lines) => {
            resolve(await Promise.all(
              lines.map(async (line, index) => {
                return new Promise((resolve, reject) => {
                  Papa.parse(line, {
                    ...this.config,
                    ...{
                      header: false, // overload, header is handled locally
                      complete: (result) => {
                        const { data: { [0]: data } = {}, errors } = result
                        resolve({ data, errors })
                      }
                    }
                  })
                })
              })
            ))
          })
        })
      }

      const staticMapping = this.staticMapping.reduce((staticMapping, { key, value }) => {
        staticMapping[key] = value
        return staticMapping
      }, {})

      let start = ((this.config.header) ? 1 : 0)
      let length = 100

      parseLines(start, length).then(async (lines) => {
        const zippedLines = lines.reduce((zippedLines, { data, errors }) => {
          zippedLines.push({
            ...data.reduce((line, value, index) => {
              if (this.importMapping[index]) {
                line[this.importMapping[index]] = value
              }
              return line
            }, {}),
            ...staticMapping
          })
          return zippedLines
        }, [])

        await this.importFunction(zippedLines).then((result) => {

          console.log('resolved', result)
        }).catch((err) => {

          console.log('rejected', err)
        })

        console.log('DONE')

      })
    }
  },
  validations () {
    let eachStaticMapping = {}
    let eachPreviewData = {}
    let index
    this.fields.forEach((field) => {
      if ('validators' in field) {
        index = this.staticMapping.findIndex(f => f.key === field.value)
        if (index > -1) {
          eachStaticMapping[field.value] = {
            value: {
              ...{ [this.$i18n.t('Value required.')]: required },
              ...field.validators
            }
          }
        }
        index = this.importMapping.findIndex(f => f === field.value)
        if (index > -1) {
          eachPreviewData[index] = field.validators
        }
      }
    })
    return {
      importMapping: {
        [this.$i18n.t('Map at least 1 column.')]: conditional(this.importMapping.filter(row => row).length > 0),
        [this.$i18n.t('Missing required fields.')]: conditional(this.fields.filter(field => field.required && !this.importMapping.includes(field.value)).length === 0)
      },
      staticMapping: { ...this.staticMapping.map(m => eachStaticMapping[m.key]) },
      preview: {
        required,
        $each: {
          data: eachPreviewData
        }
      }
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
    },
    previewColumnCount: {
      handler (a, b) {
        this.importMapping = new Array(a)
          .fill(null)
          .map((_, index) => (index in this.importMapping) ? this.importMapping[index] : null)
      }
    },
    importMapping: {
      handler (a, b) {
        this.$nextTick(() => {
          if (this.$v.$anyDirty) {
            this.$v.$touch()
          }
        })
      },
      deep: true
    },
    staticMapping: {
      handler (a, b) {
        this.$nextTick(() => {
          if (this.$v.$anyDirty) {
            this.$v.$touch()
          }
        })
      },
      deep: true
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
  .pf-csv-import-form-group {
    &.is-invalid {
      .input-group {
        border: 1px solid #dc3545;
        border-radius: .25rem;
        select {
          border: 0px;
        }
      }
    }
  }
}
.cursor-pointer {
  cursor: pointer;
}
</style>
