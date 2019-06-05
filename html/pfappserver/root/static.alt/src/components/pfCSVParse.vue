<!--
 * Component to parse CSV
 *
 * Supports:
 *  Multiple file isolation
 *  Papa parsing (See: https://www.papaparse.com/)
 *  Table output with user-selected mappings
 *  Active validation on fields w/ Vuelidate
 *
 *  Basic Usage:
 *
 *  <pf-csv-parse @input="onImport" :file="file" :fields="fields"></pf-csv-parse>
 *
 *  Properties:
 *
 *    `file`: (object) -- file Object from pfFormUpload {
 *      result: (string) -- the file contents,
 *      lastModified: (int) -- timestamp-milliseconds of when the file was last modified,
 *      name: (string) -- the original filename (no path),
 *      size: (int) -- the file size in Bytes,
 *      type: (string) -- the mime-type of the file (eg: 'text/plain').
 *    }
 *
 *    `fields`: (array) -- Fields for user-selected mappings [
 *      {
 *        value: (string) -- key name,
 *        text: (string) -- localized label,
 *        types: (array) -- Input type(s), see globals/pfField.js
 *        required: (boolean) -- required in field mappings, not shown in static mappings,
 *        validators: (object) -- list of vuelidate validators, validated before formatting,
 *        formatter: (value, key, item) -- field formatter, does not affect table data, formatted after validation.
 *      },
 *      ...
 *    ]
 *
 *    `event-listen` (boolean) -- listen to keyboard/mouse events
 *
 *  Events:
 *
 *    @input: emitted w/ (`exportModel`, `this`)
 *      `exportModel`: (array) -- a remapped array of objects based on user-mappings and clean vuelidations
 *      `this`: (object) -- forward `this` to allow direct modification of this.tableValues[index]... _rowVariant and _rowMessage.
 *
-->
<template>
  <b-form @submit.prevent="doExport()">
    <b-card no-body>
      <b-tabs v-model="tabIndex" card>

        <b-tab :title="$t('CSV File Contents')">
          <ace-editor
            v-model="file.result"
            :lang="mode"
            :theme="theme"
            :height="editorHeight"
            :options="editorOptions"
            @init="initEditor"
          ></ace-editor>
        </b-tab>

        <b-tab :title="$t('CSV Parser Options')">
          <b-row>
            <b-col cols="6">
              <pf-form-input v-model="config.encoding" :column-label="$t('Encoding')"
              :text="$t('The encoding to use when opening local files.')"/>
              <pf-form-input v-model="config.delimiter" :column-label="$t('Delimiter')" placeholder="auto"
              :text="$t('The delimiting character. Leave blank to auto-detect from a list of most common delimiters.')"/>
              <pf-form-input v-model="config.newline" :column-label="$t('Newline')" placeholder="auto"
              :text="$t('The newline sequence. Leave blank to auto-detect. Must be one of \\r, \\n, or \\r\\n.')"/>
              <pf-form-toggle v-model="config.header" :column-label="$t('Header')"
              :values="{checked: true, unchecked: false}" text="If enbabled, the first row of parsed data will be interpreted as field names."
              >{{ (config.header) ? $t('Yes') : $t('No') }}</pf-form-toggle>
              <pf-form-toggle v-model="config.skipEmptyLines" :column-label="$t('Skip Empty Lines')"
              :values="{checked: true, unchecked: false}" text="If enabled, lines that are completely empty (those which evaluate to an empty string) will be skipped."
              >{{ (config.skipEmptyLines) ? $t('Yes') : $t('No') }}</pf-form-toggle>
            </b-col>
            <b-col cols="6">
              <pf-form-input v-model="config.quoteChar" :column-label="$t('Quote Character')"
              :text="$t('The character used to quote fields. The quoting of all fields is not mandatory. Any field which is not quoted will correctly read.')"/>
              <pf-form-input v-model="config.escapeChar" :column-label="$t('Escape Character')"
              :text="$t('The character used to escape the quote character within a field. If not set, this option will default to the value of quoteChar, meaning that the default escaping of quote character within a quoted field is using the quote character two times.')"/>
              <pf-form-input v-model="config.comments" :column-label="$t('Comments')"
              :text="$t('A string that indicates a comment (for example, \'#\' or \'//\').')"/>
              <pf-form-input v-model="config.preview" :column-label="$t('Preview')"
              :text="$t('If > 0, only that many rows will be parsed.')"/>
            </b-col>
          </b-row>
        </b-tab>

        <slot><!-- Additional tabs --></slot>

        <b-tab :title="$t('Import Data')">
          <b-container fluid v-if="items.length" class="overflow-auto">
            <b-row align-v="center" class="float-right">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[10,25,50,100]" :disabled="isLoading"
                @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" v-model="currentPage" :per-page="pageSizeLimit" :total-rows="totalRows" :disabled="isLoading"
              @change="onPageChange" />
            </b-row>
          </b-container>
          <b-table
            v-if="items.length"
            v-model="tableValues"
            :disabled="isLoading"
            :ref="uuidStr('table')"
            :items="items" :fields="columns"
            :sort-by="sortBy" :sort-desc="sortDesc"
            @sort-changed="onSortingChanged"
            @row-clicked="onRowClick"
            @head-clicked="clearSelected"
            hover outlined responsive show-empty no-local-sorting striped>
            <template slot="HEAD_actions" slot-scope="head">
              <div class="text-center">
                <b-form-checkbox id="checkallnone" v-model="selectAll" @change="onSelectAllChange"></b-form-checkbox>
                <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{ $t('Select None [ALT+N]') }}</b-tooltip>
                <b-tooltip target="checkallnone" placement="right" v-else>{{ $t('Select All [ALT+A]') }}</b-tooltip>
              </div>
            </template>
            <template slot="actions" slot-scope="data">
              <div class="text-center">
                <b-form-checkbox :id="data.value" :value="data.item" :disabled="rowDisabled(data.index)" v-model="selectValues" @click.native.stop="onToggleSelected($event, data.index)">
                  <div v-if="rowMessage(data.index)" v-b-tooltip.hover.right :title="rowMessage(data.index)">
                    <icon name="exclamation-triangle" class="ml-1"></icon>
                  </div>
                </b-form-checkbox>
              </div>
            </template>

            <template slot="top-row" slot-scope="data">
              <td v-for="column in data.columns" :key="column" :class="['p-1', {'table-danger': column === 1 && selectValues.length === 0 }]">
                <pf-form-select v-if="column > 1"
                  v-model="tableMapping[column - 2]"
                  :vuelidate="$v.tableMapping"
                  >
                  <template slot="first">
                    <option :value="null">-- {{ $t('Ignore field') }} --</option>
                  </template>
                  <optgroup :label="$t('Required fields')">
                    <option v-for="option in tableMappingOptions().filter(o => o.required)" :key="option.value" :value="option.value" :disabled="option.disabled" :class="{'bg-success text-white': !option.disabled}">{{ option.text }}</option>
                  </optgroup>
                  <optgroup :label="$t('Optional fields')">
                    <option v-for="option in tableMappingOptions().filter(o => !o.required)" :key="option.value" :value="option.value" :disabled="option.disabled" :class="{'bg-warning': !option.disabled}">{{ option.text }}</option>
                  </optgroup>
                </pf-form-select>
              </td>
            </template>
            <template slot="bottom-row" slot-scope="data" class="bg-white">
              <td :colspan="data.columns">

                <b-row align-v="start" class="mx-0 px-0 mb-3" v-for="(staticMap, index) in staticMapping" :key="index">
                  <b-col cols="3" class="ml-0 mr-1 px-0">
                    <b-form-select v-model="staticMapping[index].key" :options="staticMappingOptions()"></b-form-select>
                  </b-col>
                  <b-col cols="8" class="mx-0 px-0">

                    <!-- BEGIN SUBSTRING -->
                    <pf-form-input v-if="isFieldType(substringValueType, staticMapping[index])"
                    v-model="staticMapping[index].value"
                    :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                    :vuelidate="$v.staticMapping[index].value"
                    ></pf-form-input>

                    <!-- BEGIN DATE -->
                    <pf-form-datetime v-else-if="isFieldType(dateValueType, staticMapping[index])"
                    v-model="staticMapping[index].value"
                    :config="{format: 'YYYY-MM-DD'}"
                    :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                    :vuelidate="$v.staticMapping[index].value"
                    ></pf-form-datetime>

                    <!-- BEGIN DATETIME -->
                    <pf-form-datetime v-else-if="isFieldType(datetimeValueType, staticMapping[index])"
                    v-model="staticMapping[index].value"
                    :config="{format: 'YYYY-MM-DD HH:mm:ss'}"
                    :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                    :vuelidate="$v.staticMapping[index].value"
                    ></pf-form-datetime>

                    <!-- BEGIN PREFIXMULTIPLIER -->
                    <pf-form-prefix-multiplier v-else-if="isFieldType(prefixmultiplierValueType, staticMapping[index])"
                    v-model="staticMapping[index].value"
                    :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                    :vuelidate="$v.staticMapping[index].value"
                    ></pf-form-prefix-multiplier>

                    <!-- BEGIN YESNO -->
                    <pf-form-toggle  v-else-if="isFieldType(yesnoValueType, staticMapping[index])"
                    v-model="staticMapping[index].value"
                    :values="{checked: 'yes', unchecked: 'no'}"
                    :vuelidate="$v.staticMapping[index].value"
                    >{{ (staticMapping[index].value === 'yes') ? $t('Yes') : $t('No') }}</pf-form-toggle>

                    <!-- BEGIN GENDER -->
                    <pf-form-chosen v-else-if="isFieldType(genderValueType, staticMapping[index])"
                    :value="staticMapping[index].value"
                    label="name"
                    track-by="value"
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
                    :options="fieldTypeValues[sourceValueType](context)"
                    :vuelidate="$v.staticMapping[index].value"
                    @input="staticMapping[index].value = $event"
                    collapse-object
                    ></pf-form-chosen>

                    <!-- BEGIN ***CATCHALL*** -->
                    <pf-form-input v-else
                    v-model="staticMapping[index].value"
                    :class="{ 'border-danger': $v.staticMapping[index].value.$anyError }"
                    :vuelidate="$v.staticMapping[index].value"
                    ></pf-form-input>

                  </b-col>
                  <b-col>
                    <icon name="trash-alt" class="my-2" style="cursor: pointer" @click.native="deleteStatic(index)" v-b-tooltip.hover.right.d300 :title="$t('Remove static field')"></icon>
                  </b-col>
                </b-row>

                <b-row fluid class="mx-0 px-0 mb-3" v-if="staticMappingOptions().filter(f => f.value && !f.disabled).length > 0">
                  <b-col cols="3" class="ml-0 mr-1 px-0">
                    <b-form-select v-model="staticMappingNew" :options="staticMappingOptions()">
                      <template slot="first">
                        <option :value="null" disabled>-- {{ $t('Choose static field') }} --</option>
                      </template>
                    </b-form-select>
                  </b-col>
                  <b-col cols="8" class="mx-0 px-0">
                    <b-button type="button" variant="outline-secondary" :disabled="typeof staticMappingNew !== 'string'" @click.prevent="addStatic">
                      <icon name="plus-circle" class="mr-1"></icon>
                      {{ $t('Add static field') }}
                    </b-button>
                  </b-col>
                </b-row>

                <b-container fluid class="mx-0 px-0 mt-3 footer-errors">
                  <b-button type="submit" variant="primary" :disabled="$v.$anyError" @mouseenter="$v.$touch()">
                    <icon v-if="isLoading" name="circle-notch" spin class="mr-1"></icon>
                    <icon v-else name="download" class="mr-1"></icon>
                    {{ $t('Import') + ' ' + selectValues.length + ' ' + $t('selected rows') }}
                  </b-button>
                  <b-form-group v-if="$v.staticMapping.$anyError" :state="false" :invalid-feedback="$t('Static field mappings invalid.')"></b-form-group>
                  <b-form-group v-if="$v.tableMapping.$anyError" :state="false" :invalid-feedback="$t('Table field mappings invalid.')"></b-form-group>
                  <b-form-group v-if="$v.selectValues.$anyError" :state="false" :invalid-feedback="$t('Select at least 1 row.')"></b-form-group>
                </b-container>
              </td>
            </template>

          </b-table>
          <b-container v-else class="my-5">
            <b-row class="justify-content-md-center text-secondary">
              <b-col cols="12" md="auto">
                <icon v-if="isLoading" name="sync" scale="2" spin></icon>
                <b-media v-else>
                  <icon name="ruler-combined" scale="2" slot="aside"></icon>
                  <h5 v-t="'CSV could not be parsed'"></h5>
                  <p class="font-weight-light">{{ $t('Please refine CSV parser options.') }}</p>
                </b-media>
              </b-col>
            </b-row>
          </b-container>
        </b-tab>

      </b-tabs>
    </b-card>
  </b-form>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import Papa from 'papaparse'
import uuidv4 from 'uuid/v4'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormToggle from '@/components/pfFormToggle'
import pfMixinSelectable from '@/components/pfMixinSelectable'
import {
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import {
  conditional
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

const aceEditor = require('vue2-ace-editor')
const { validationMixin } = require('vuelidate')

export default {
  name: 'pf-csv-parse',
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormPrefixMultiplier,
    pfFormSelect,
    pfFormToggle,
    aceEditor
  },
  mixins: [
    pfMixinSelectable,
    validationMixin
  ],
  props: {
    storeName: { // from router
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
      default: null
    },
    mode: {
      type: String,
      default: 'ini'
    },
    theme: {
      type: String,
      default: 'cobalt'
    },
    defaultStaticMapping: {
      type: Array,
      default: () => { return [] }
    }
  },
  data () {
    return {
      tabIndex: 0,
      tableValues: Array,
      tableMapping: Array,
      staticMapping: Array,
      staticMappingNew: null,
      exportModel: Array,
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
      uuid: uuidv4(), // unique id for multiple instances of this component
      config: { // Papa parse config
        delimiter: '', // auto-detect
        newline: '', // auto-detect
        quoteChar: '"',
        escapeChar: '"',
        header: true,
        trimHeaders: true,
        dynamicTyping: false,
        preview: '',
        encoding: 'utf-8',
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
      meta: null,
      data: null,
      sortBy: null,
      sortDesc: false,
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 100,
      fieldTypeValues: fieldTypeValues,
      parentNodes: [],
      editor: null,
      editorHeight: '60vh',
      editorOptions: {
        enableLiveAutocompletion: true,
        showPrintMargin: false,
        tabSize: 4
      }
    }
  },
  validations () {
    // dynamically apply vuelidate validations
    let eachSelectValues = {}
    let eachStaticMapping = {}
    let eachExportModel = {}

    this.fields.forEach((field, index) => {
      if ('validators' in field) {
        if (typeof this.tableMapping !== 'function' && this.tableMapping.length > 0) {
          let index = this.tableMapping.findIndex(f => f === field.value)
          if (index !== -1) {
            eachSelectValues[this.meta.fields[index]] = field.validators
          }
        }
        if (typeof this.staticMapping !== 'function' && this.staticMapping.length > 0) {
          let index = this.staticMapping.findIndex(f => f.key === field.value)
          if (index !== -1) {
            eachStaticMapping[field.value] = {
              value: Object.assign({
                [this.$i18n.t('Value required.')]: required /* Require static field if defined */
              }, field.validators)
            }
          }
        }
        eachExportModel[field.value] = field.validators
      }
    })

    let funcStaticMapping = {}
    if (typeof this.staticMapping !== 'function' && this.staticMapping.length > 0) {
      // use functional validations
      // https://github.com/monterail/vuelidate/issues/166#issuecomment-319924309
      funcStaticMapping = { ...this.staticMapping.map(m => eachStaticMapping[m.key]) }
    }

    return {
      selectValues: {
        [this.$i18n.t('Select at least 1 row.')]: required,
        $each: eachSelectValues
      },
      tableMapping: {
        [this.$i18n.t('Map at least 1 column.')]: conditional(this.tableMapping instanceof Array && this.tableMapping.filter(row => row).length > 0),
        [this.$i18n.t('Missing required fields.')]: conditional(this.fields.filter(field => field.required && this.tableMapping instanceof Array && !this.tableMapping.includes(field.value)).length === 0)
      },
      staticMapping: funcStaticMapping,
      exportModel: {
        required,
        $each: eachExportModel
      }
    }
  },
  methods: {
    uuidStr (section) {
      return (section || 'default') + '-' + this.uuid
    },
    parseDebounce () {
      if (this.parseTimeout) clearTimeout(this.parseTimeout)
      this.parseTimeout = setTimeout(this.parse, 100)
    },
    parse () {
      const _this = this
      Papa.parse(this.file.result, Object.assign({}, this.config, {
        complete (results) {
          _this.meta = results.meta
          // CSV header (1st-row) may be ignored (See Papa::config.header)
          if (!results.meta.fields || results.meta.fields.length === 0) {
            // find widest row
            const size = results.data.reduce((max, row) => (max > row.length) ? max : row.length, 0)
            _this.meta.fields = new Array(size)
            for (let i = 0; i < size; i++) {
              // fields must be unique
              _this.meta.fields[i] = i.toString()
            }
            // Papa flattens data into an Array (not Object) when CSV header is skipped,
            //  remap data from Array into Object
            _this.data = results.data.reduce((data, row) => {
              const mappedRow = row.reduce((mappedRow, column, index) => {
                mappedRow[index.toString()] = column
                return mappedRow
              }, {})
              data.push(mappedRow)
              return data
            }, [])
          } else {
            _this.data = results.data
          }
          // setup null placeholders in tableMapping Array
          _this.tableMapping = new Array(_this.meta.fields.length).fill(null)
          // init staticMapping
          _this.staticMapping = _this.defaultStaticMapping
          // clear selectValues artifacts
          _this.selectValues = []
        },
        error (errors) {
          _this.data = null
          _this.meta = null
          throw new Error(errors)
        },
        abort () {
          _this.data = null
          _this.meta = null
        }
      }))
    },
    reservedMappingOptions () {
      // aggregate all selected fields
      let options = []
      options.push(...this.tableMapping.filter(val => val))
      options.push(...this.staticMapping.map(val => val.key))
      return options
    },
    tableMappingOptions () {
      let fields = this.fields
      const reserved = this.reservedMappingOptions()
      fields.forEach((f, i) => {
        if (!f.value) return // ignore null
        // disable fields selected elsewhere
        fields[i].disabled = reserved.includes(f.value)
      })
      return fields
    },
    staticMappingOptions () {
      let fields = []
      fields.push(...this.fields.filter(field => !field.required))
      const reserved = this.reservedMappingOptions()
      fields.forEach((f, i) => {
        if (!f.value) return // ignore null
        // disable fields selected elsewhere
        fields[i].disabled = reserved.includes(f.value)
      })
      return fields
    },
    addStatic () {
      if (this.reservedMappingOptions().includes(this.staticMappingNew)) return
      this.staticMapping.push({ key: this.staticMappingNew, value: null })
      this.staticMappingNew = null
    },
    deleteStatic (index) {
      this.staticMapping.splice(index, 1)
    },
    buildExportModel () {
      let staticMapping = {}
      this.staticMapping.forEach((mapping) => {
        const field = this.fields.filter(field => field.value === mapping.key)[0]
        staticMapping[mapping.key] = mapping.value
        if (field && 'formatter' in field) {
          staticMapping[mapping.key] = field.formatter(mapping.value, mapping.key, staticMapping)
        }
      })
      const cheatSheet = this.tableMapping.reduce((cheatSheet, mapping, index) => {
        // (tableMapping) [null, 'mac'] + (meta.fields) ['colA', 'colB']
        //    => (cheatSheet) {colB: 'mac'}
        if (mapping !== null) cheatSheet[this.meta.fields[index]] = mapping
        return cheatSheet
      }, {})
      this.exportModel = this.selectValues.reduce((exportModel, selectValue, index) => {
        // (selectValues) [ {colA: 'W', colB: 'X'}, {colA: 'Y', colB: 'Z'} ] + (cheatSheet) {colB: 'mac'}
        //    => (exportModel) [ {mac: 'X'}, {mac: 'Z'} ]
        // ignore selectValues with validation errors
        if (!this.$v.selectValues.$each.$iter[index].$anyError) {
          let mappedRow = Object.keys(selectValue).reduce((mappedRow, key) => {
            if (cheatSheet[key]) mappedRow[cheatSheet[key]] = (selectValue[key] === '') ? null : selectValue[key]
            return mappedRow
          }, staticMapping)
          // format fields
          Object.keys(mappedRow).forEach((key) => {
            const field = this.fields.filter(field => field.value === key)[0]
            if (field && 'formatter' in field) {
              mappedRow[key] = field.formatter(mappedRow[key], key, mappedRow)
            }
          })
          // dereference mappedRow
          mappedRow = JSON.parse(JSON.stringify(mappedRow))
          // add pointer reference to tableValue for callback
          let tableValueIndex = this.tableValues.findIndex(v => v === selectValue)
          mappedRow._tableValueIndex = tableValueIndex
          exportModel.push(mappedRow)
        }
        return exportModel
      }, [])
    },
    doExport (event) {
      this.$emit('input', this.exportModel, this)
    },
    onPageSizeChange () {
      this.requestPage = 1 // reset to the first page
    },
    onPageChange () {
      this.currentPage = this.requestPage
    },
    onSortingChanged (params) {
      this.requestPage = 1 // reset to the first page
      this.sortBy = params.sortBy
      this.sortDesc = params.sortDesc
      this.data.sort((a, b) => {
        return a[params.sortBy].localeCompare(b[params.sortBy]) * ((params.sortDesc) ? -1 : 1)
      })
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
    rowDisabled (index) {
      const { tableValues: { [index]: { _rowDisabled = false } = {} } = [] } = this
      return _rowDisabled
    },
    rowMessage (index) {
      const { tableValues: { [index]: { _rowMessage = null } = {} } = [] } = this
      return _rowMessage
    },
    initEditor (instance) {
      // Load ACE editor extensions
      require('brace/ext/language_tools')
      require(`brace/mode/${this.mode}`)
      require(`brace/theme/${this.theme}`)
      this.editor = instance
      this.editor.setAutoScrollEditorIntoView(true)
    }
  },
  computed: {
    items () {
      if (!this.data) return []
      // paginated
      const begin = this.pageSizeLimit * (this.currentPage - 1)
      const end = begin + this.pageSizeLimit
      return this.data.slice(begin, end)
    },
    totalRows () {
      return (this.data) ? this.data.length : 0
    },
    columns () {
      const columns = [{ // for pfMixinSelectable
        key: 'actions',
        label: this.$i18n.t('Actions'),
        sortable: false,
        visible: true,
        locked: true,
        variant: (this.selectValues.length > 0) ? '' : 'danger'
      }]
      if (this.meta && this.meta.fields) {
        columns.push(...this.meta.fields.map((field, index) => {
          let variant = (this.tableMapping[index] === null) // is it mapped?
            ? null // not mapped
            : (this.fields.filter(f => f.value === this.tableMapping[index])[0].required) // is it required?
              ? 'success' // is required
              : 'warning' // not required
          return {
            key: field,
            label: field,
            sortable: true,
            visible: true,
            locked: true,
            variant: variant
          }
        }))
      }
      return columns
    }
  },
  watch: {
    config: {
      handler: function (a, b) {
        this.parseDebounce()
      },
      deep: true
    },
    tableMapping: {
      handler: function (a, b) {
        this.selectValues.forEach(row => { row._rowVariant = 'info' })
        this.$v.$touch()
        this.buildExportModel()
      },
      deep: true
    },
    staticMapping: {
      handler: function (a, b) {
        this.$v.$touch()
        this.buildExportModel()
      },
      deep: true
    },
    selectValues: {
      handler: function (a, b) {
        if (a.length === b.length) return
        this.$v.$touch()
        this.buildExportModel()
      },
      deep: true
    },
    '$v': {
      handler: function (a, b) {
        if (typeof this.tableValues === 'function') return
        // debounce
        if (this.validateTimeout) clearTimeout(this.validateTimeout)
        this.validateTimeout = setTimeout(() => {
          // reset all cellVariants
          this.tableValues.forEach((row, index, values) => {
            this.tableValues[index]._cellVariants = {}
          })
          // iterate selectValues and exec validations
          if (a.selectValues.$each.$iter) {
            Object.entries(a.selectValues.$each.$iter).forEach(f => {
              let [index, field] = f
              // set row variant based on validation error on tableValue (not selectValue)
              if (field.$anyError) {
                const row = this.tableValues.find(row => row === a.selectValues.$model[index])
                if (row._rowVariant !== '') {
                  // clear row variant, allows cell variant to show
                  row._rowVariant = ''
                }
                Object.keys(field.$model).forEach(key => {
                  if (field[key] && field[key].$anyError) {
                    row._cellVariants.actions = 'danger'
                    row._cellVariants[key] = 'danger'
                  }
                })
              }
            })
          }
          this.$forceUpdate()
        }, 100)
      },
      deep: true
    }
  },
  mounted () {
    // reset `file` when page reloaded, remove w/ $store implementation
    this.parseDebounce()
  },
  beforeDestroy () {
    if (this.parseTimeout) {
      clearTimeout(this.parseTimeout)
    }
    if (this.validateTimeout) {
      clearTimeout(this.validateTimeout)
    }
  }
}
</script>

<style lang="scss" scoped>
.collapsed > svg.when-opened,
:not(.collapsed) > svg.when-closed {
  display: none;
}
header > :not(.collapsed) {
  /* btn-primary */
  background-color: #007bff;
  color: #fff;
  border-color: #007bff;
  transition: all 300ms ease;
}
.footer-errors {
  & .form-group:nth-of-type(1) {
    margin-top: 1rem;
  }
  & .form-group:not(:last-child) {
    margin-bottom: 0;
  }
}
</style>
