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
 *  <pf-csv-parse @input="onImport" :file="file" :fields="fields" no-init-bind-keys></pf-csv-parse>
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
 *    `no-init-bind-keys` -- for pfMixinSelectable, don't bind onKeyDown for multiple instances
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
    <b-card-body>
      <b-tabs pills card>

        <b-tab :title="$t('CSV File Contents')">
          <b-form-textarea
          :disabled="isLoading"
          class="line-numbers" size="sm" rows="1" max-rows="40"
          v-model="file.result"
          v-on:input="parseDebounce"
          ></b-form-textarea>
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

        <b-tab :title="$t('Import Data')">
          <b-container fluid v-if="items.length">
            <b-row align-v="center" class="float-right">
              <b-form inline class="mb-0">
                <b-form-select class="mb-3 mr-3" size="sm" v-model="pageSizeLimit" :options="[10,25,50,100]" :disabled="isLoading"
                @input="onPageSizeChange" />
              </b-form>
              <b-pagination align="right" v-model="requestPage" :per-page="pageSizeLimit" :total-rows="totalRows" :disabled="isLoading"
              @input="onPageChange" />
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
          hover outlined responsive show-empty no-local-sorting>
            <template slot="HEAD_actions" slot-scope="head">
              <div class="text-center">
                <input type="checkbox" id="checkallnone" v-model="selectAll" @change="onSelectAllChange" @click.stop />
                <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{$t('Select None [ALT+N]')}}</b-tooltip>
                <b-tooltip target="checkallnone" placement="right" v-else>{{$t('Select All [ALT+A]')}}</b-tooltip>
              </div>
            </template>
            <template slot="actions" slot-scope="data">
              <div class="text-center">
                <input type="checkbox" :id="data.value" :value="data.item" :disabled="tableValues[data.index]._rowDisabled" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)" />
                <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._rowMessage" v-b-tooltip.hover.right :title="tableValues[data.index]._rowMessage"></icon>
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

                    <!-- BEGIN ROLE -->
                    <pf-form-chosen v-else-if="isFieldType(roleValueType, staticMapping[index])"
                    :value="staticMapping[index].value"
                    label="name"
                    track-by="value"
                    :options="fieldTypeValues[roleValueType]($store)"
                    :vuelidate="$v.staticMapping[index].value"
                    @input="staticMapping[index].value = $event"
                    collapse-object
                    ></pf-form-chosen>

                    <!-- BEGIN SOURCE -->
                    <pf-form-chosen v-else-if="isFieldType(sourceValueType, staticMapping[index])"
                    :value="staticMapping[index].value"
                    label="name"
                    track-by="value"
                    :options="fieldTypeValues[sourceValueType]($store)"
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
                  <h5>CSV could not be parsed</h5>
                  <p class="font-weight-light">{{ $t('Please refine CSV parser options.') }}</p>
                </b-media>
              </b-col>
            </b-row>
          </b-container>
        </b-tab>

      </b-tabs>
    </b-card-body>
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

const { validationMixin } = require('vuelidate')

export default {
  name: 'pf-csv-parse',
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormPrefixMultiplier,
    pfFormSelect,
    pfFormToggle
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
    }
  },
  data () {
    return {
      tableValues: Array,
      tableMapping: Array,
      staticMapping: Array,
      staticMappingNew: null,
      exportModel: Array,
      substringValueType:        fieldType.SUBSTRING,
      dateValueType:             fieldType.DATE,
      datetimeValueType:         fieldType.DATETIME,
      prefixmultiplierValueType: fieldType.PREFIXMULTIPLIER,
      genderValueType:           fieldType.GENDER,
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
      fieldTypeValues: fieldTypeValues
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
          _this.staticMapping = []
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
textarea.line-numbers {
  /* http://i.imgur.com/2cOaJ.png */
  background: url('data:image/png;base64,\
  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\
  MF7/F2AA8iiPy4nAgBYAAAAASUVORK5CYII=') no-repeat 0px 0px;
  background-attachment: local;
  padding-left: 35px;
  padding-top: 12px;
  border-color:#ccc;
  font-family: monospace;
  line-height: 16px !important;
  font-size: 14px !important;
  white-space: nowrap;
  overflow: auto;
  /**
    * TODO:
    * https://stackoverflow.com/questions/1995370/html-adding-line-numbers-to-textarea
    * https://www.fourkitchens.com/blog/article/fix-scrolling-performance-css-will-change-property/
  **/
}
header > :not(.collapsed) {
  /* btn-primary */
  color: #fff;
  background-color: #007bff;
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
