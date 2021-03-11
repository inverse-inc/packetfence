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
        <div class="card p-3" v-else>
          <!-- preview options -->
          <b-row align-v="center">
            <b-col cols="auto" class="mr-auto">
              <h4 v-t="'Import Mappings'"></h4>
              <p v-t="'Map the required fields and any optional static fields.'"></p>
            </b-col>
            <b-col cols="auto" class="ml-auto text-right pb-3">
              <b-button :disabled="isDisabled || perPage === 1"
                class="pr-3 text-secondary" variant="light" size="sm" pill
                @click="deletePageColumn()"
              ><icon name="minus-circle" class="mr-1"></icon> {{ $t('Remove Line') }}</b-button>

              <b-button :disabled="isDisabled"
                class="ml-2 pr-3 text-secondary" variant="light" size="sm" pill
                @click="addPageColumn()"
              ><icon name="plus-circle" class="mr-1"></icon> {{ $t('Add Line') }}</b-button>
            </b-col>
            <b-col cols="auto">
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
              <template v-for="(_, colIndex) in new Array(perPage)">
                <b-col class="text-nowrap" :key="`col-${colIndex}`">
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
            <b-row class="pf-csv-import-table-row" v-for="(_, rowIndex) in previewColumnCount" :key="`row-${rowIndex}`">
              <b-col>
                <b-form-group
                  :state="($v && 'importMapping' in $v && $v.importMapping.$invalid) ? false : null"
                  :invalid-feedback="getImportMappingVuelidateFeedback()"
                  class="my-1 pf-csv-import-form-group"
                >
                  <b-input-group>
                    <template v-slot:append v-if="rowVariant(rowIndex)">
                      <b-button variant="light" class="text-secondary pb-1" :disabled="isDisabled" @click="deleteImportMapping(rowIndex)">
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
                        <option v-for="option in importMappingOptions.filter(o => o.required)" :key="`required-${option.value}`" :value="option.value" :disabled="option.disabled" :class="{'bg-success text-white': !option.disabled}">{{ option.text }}</option>
                      </optgroup>
                      <optgroup :label="$t('Optional fields')">
                        <option v-for="option in importMappingOptions.filter(o => !o.required)" :key="`optional-${option.value}`" :value="option.value" :disabled="option.disabled" :class="{'bg-warning': !option.disabled}">{{ option.text }}</option>
                      </optgroup>
                    </b-form-select>
                  </b-input-group>
                </b-form-group>
              </b-col>
              <template v-for="(_, colIndex) in new Array(perPage)">
                <b-col class="col-overflow-hidden" :class="(importMapping[rowIndex]) ? 'text-black' : 'text-black-50'" :key="`col-${colIndex}`">
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
                  <b-form-select v-model="staticMap.key" :options="staticMappingOptions" :disabled="isDisabled" @change="focusStaticMapping(staticMap.key)"></b-form-select>
                </b-input-group>
              </b-col>
              <b-col>

                <pf-form-chosen v-if="isComponentType([componentType.SELECTMANY, componentType.SELECTONE], staticMap)"
                  :value="staticMap.value"
                  label="text"
                  track-by="value"
                  :ref="staticMap.key"
                  :disabled="isDisabled"
                  :multiple="isComponentType([componentType.SELECTMANY], staticMap)"
                  :options="getStaticMappingOptions(staticMap)"
                  @input="staticMap.value = $event"
                  collapse-object
                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
                ></pf-form-chosen>

                <pf-form-input v-else-if="isComponentType([componentType.SUBSTRING], staticMap)"
                  v-model="staticMap.value"
                  :ref="staticMap.key"
                  :disabled="isDisabled"
                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
                ></pf-form-input>

                <pf-form-datetime v-else-if="isComponentType([componentType.DATE], staticMap)"
                  v-model="staticMap.value"
                  :ref="staticMap.key"
                  :config="{format: 'YYYY-MM-DD'}"
                  :disabled="isDisabled"
                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
                ></pf-form-datetime>

                <pf-form-datetime v-else-if="isComponentType([componentType.DATETIME], staticMap)"
                  v-model="staticMap.value"
                  :ref="staticMap.key"
                  :config="{format: 'YYYY-MM-DD HH:mm:ss'}"
                  :disabled="isDisabled"
                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
                ></pf-form-datetime>

                <pf-form-prefix-multiplier v-else-if="isComponentType([componentType.PREFIXMULTIPLIER], staticMap)"
                  v-model="staticMap.value"
                  :ref="staticMap.key"
                  :disabled="isDisabled"
                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
                ></pf-form-prefix-multiplier>

                <pf-form-toggle  v-else-if="isComponentType([componentType.TOGGLE], staticMap)"
                  v-model="staticMap.value"
                  :ref="staticMap.key"
                  :disabled="isDisabled"
                  :values="{checked: 'yes', unchecked: 'no'}"
                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
                >{{ (staticMap.value === 'yes') ? $t('Yes') : $t('No') }}</pf-form-toggle>

                <pf-form-input v-else
                  v-model="staticMap.value"
                  :ref="staticMap.key"
                  :disabled="isDisabled"
                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
                ></pf-form-input>

              </b-col>
              <b-col v-for="(_) in new Array(perPage - 1)" :key="_">-</b-col>
            </b-row>
            <b-row class="pf-csv-import-table-row" v-if="staticMappingOptions.filter(f => f.value && !f.disabled).length > 0">
              <b-col>
                <b-form-select v-model="staticMappingSelect" :options="staticMappingOptions" :disabled="isDisabled" @change="addStaticMapping()">
                  <template v-slot:first>
                    <option :value="null" disabled>-- {{ $t('Choose static field') }} --</option>
                  </template>
                </b-form-select>
              </b-col>
              <b-col v-for="(_) in new Array(perPage)" :key="_"><!-- NOP --></b-col>
            </b-row>
          </div>
        </div>

        <div v-if="$slots.default && previewColumnCount > 0" class="mt-3">
          <slot name="default"/> <!-- extra content from parent component -->
        </div>
      </div>
      <b-card-footer v-if="previewColumnCount > 0" @mouseenter="$v.$touch()">
        <b-button variant="primary" class="mr-1" :disabled="isDisabled || isMappingError" @click="importStart(false)">
          <icon v-if="isImporting && !importProgress.dryRun" name="circle-notch" spin class="mr-1"></icon>
          <icon v-else name="download" class="mr-1"></icon>
          {{ $t('Import') }}
        </b-button>
        <b-button variant="outline-primary" class="mr-1" :disabled="isDisabled || isMappingError" @click="importStart(true)">
          <icon v-if="isImporting && importProgress.dryRun" name="circle-notch" spin class="mr-1"></icon>
          <icon v-else name="long-arrow-alt-down" class="mr-1"></icon>
          {{ $t('Dry Run') }}
        </b-button>
        <b-button variant="link" class="mr-1" :disabled="isDisabled" v-b-modal="`importOptions-${uuid}`">Import Options</b-button>
        <span v-if="isMappingError" class="ml-2">
          <icon name="exclamation-circle" class="text-danger mr-1"/>
          <span class="invalid-feedback d-inline" v-t="'Fix all errors before importing.'"></span>
        </span>
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

    <b-modal :id="`importProgress-${uuid}`" size="lg" :title="(importProgress.dryRun) ? $t('Dry Run Progress') : $t('Import Progress')"
      centered scrollable
      :hide-header-close="isImporting"
      :no-close-on-backdrop="isImporting"
      :no-close-on-esc="isImporting"
    >
      <b-container>
        <b-row class="justify-content-md-center text-secondary">
          <b-col cols="12">
            <b-media>
              <template v-slot:aside>
                <icon v-if="isImporting && importProgress.lastError" name="pause-circle" scale="2"></icon>
                <icon v-else-if="isImporting" name="circle-notch" scale="2" spin></icon>
                <icon v-else name="download" scale="2"></icon>
              </template>
              <template v-if="isImporting && importProgress.lastError">
                <h4 v-if="isImporting" class="mb-0">{{ (importProgress.dryRun) ? $t('Dry run paused') : $t('Import paused') }}</h4>
                <b-form-text v-t="'Review the error(s) below before continuing.'" class="mt-0 mb-3"></b-form-text>
              </template>
              <template v-else-if="isImporting">
                <h4 class="mb-0">{{ importProgress.status }}...</h4>
                <b-form-text v-t="'This operation may take a few minutes.'" class="mt-0 mb-3"></b-form-text>
              </template>
              <template v-else>
                <h4 class="mb-0">{{ importProgress.status }}</h4>
                <b-form-text class="mt-0 mb-3">{{ $t('Review the statistics below.') }}</b-form-text>
              </template>
              <b-row class="bg-light" align-v="center">
                <b-col cols="10">{{ $t('Created') }} <em v-if="importProgress.dryRun">({{ $t('not commited') }})</em></b-col>
                <b-col cols="2" class="text-right">
                  <template v-if="importProgress.dryRun || config.ignoreInsertIfNotExists" size="lg">
                    {{ importProgress.insertCount }} <icon name="lock" class="ml-1"/>
                  </template>
                  <template v-else>{{ importProgress.insertCount }}</template>
                </b-col>
              </b-row>
              <b-row align-v="center">
                <b-col cols="10">{{ $t('Updated') }} <em v-if="importProgress.dryRun">({{ $t('not commited') }})</em></b-col>
                <b-col cols="2" class="text-right">
                  <template v-if="importProgress.dryRun || config.ignoreUpdateIfExists">
                    {{ importProgress.updateCount }} <icon name="lock" class="ml-1"/>
                  </template>
                  <template v-else>{{ importProgress.updateCount }}</template>
                </b-col>
              </b-row>
              <b-row class="bg-light" align-v="center">
                <b-col cols="10">{{ $t('Skipped') }}</b-col>
                <b-col cols="2" class="text-right">{{ importProgress.skipCount }}</b-col>
              </b-row>
              <b-row align-v="center">
                <b-col cols="10">{{ $t('Failed') }}</b-col>
                <b-col cols="2" class="text-right">{{ importProgress.errorCount }}</b-col>
              </b-row>
              <b-row class="bg-light" align-v="center">
                <b-col cols="10" class="border-top">{{ $t('Total') }}</b-col>
                <b-col cols="2" class="border-top text-right">{{ importProgress.lastLine }}</b-col>
              </b-row>
            </b-media>
            <b-media v-if="isImporting && importProgress.lastError" class="mt-3">
              <template v-slot:aside>
                <icon name="exclamation-circle" scale="2" class="text-danger"></icon>
              </template>
              <h4 class="mb-0">{{ $t('Error(s) on line #{line}', { line: importProgress.lastError.line }) }}</h4>
              <b-form-text v-t="'Review the error(s) below and choose an option to continue.'" class="mt-0"></b-form-text>
              <template v-for="(error) in importProgress.lastError.errors">
                <b-row class="bg-light mt-3" align-v="center" :key="`row1-${error.key}`">
                  <b-col cols="10" class="small">{{ error.field }} </b-col>
                  <b-col cols="2" class="text-right my-1">{{ error.value }}</b-col>
                </b-row>
                <b-row :key="`row2-${error.key}`">
                  <b-col cols="10"></b-col>
                  <b-col cols="2" class="small text-right text-danger my-1">{{ error.message }}</b-col>
                </b-row>
              </template>
            </b-media>
          </b-col>
        </b-row>
      </b-container>
      <template v-slot:modal-footer>
        <template v-if="isImporting">
          <template v-if="importProgress.lastError">
            <b-button variant="outline-primary" @click="importSkipOne()" class="ml-1"><icon name="play" class="mr-1"></icon> {{ $t('Skip Error') }}</b-button>
            <b-button variant="primary" @click="importSkipAll()" class="ml-1"><icon name="forward" class="mr-1"></icon> {{ $t('Skip All Errors') }}</b-button>
          </template>
          <b-button variant="danger" @click="importCancel()" class="ml-1"><icon name="stop" class="mr-1"></icon> {{ $t('Cancel') }}</b-button>
        </template>
        <template v-else>
          <b-button v-if="importProgress.dryRun" variant="primary" class="mr-1" :disabled="isDisabled || isMappingError" @click="importStart(false)">
            <icon name="download" class="mr-1"></icon>
            {{ $t('Import') }}
          </b-button>
          <b-button variant="primary" @click="importClose()" class="ml-1">{{ $t('Close') }}</b-button>
        </template>
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
import pfFormToggle from '@/components/pfFormToggle'

import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
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
    pfFormToggle
  },
  mixins: [
    validationMixin
  ],
  props: {
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
    isSlotError: {
      type: Boolean,
      default: false
    },
    importPromise: {
      type: Function,
      default: () => {}
    }
  },
  data () {
    return {
      // expose globals
      bytes, // @/utils/bytes
      encoding, // @/utils/encoding
      componentType, // @/globals/pfField
      context: this,
      config: {
        // Papa parse config
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
      staticMapping: this.defaultStaticMapping || [], // user selection(s) for existing static mappings
      staticMappingSelect: null,

      isImporting: false,
      importProgress: {
        status: this.$i18n.t('Idle'),
        insertCount: 0,
        updateCount: 0,
        skipCount: 0,
        errorCount: 0,
        lastError: false,
        lastLine: 0,
        promise: false,
        dryRun: false,
        done: false,
        exit: false
      }
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
          importMapping: { $invalid: importMappingError = false } = {},
          staticMapping: { $invalid: staticMappingError = false } = {},
          preview: { $invalid: previewError = false } = {}
        } = {},
        isSlotError = false
      } = this
      return importMappingError || staticMappingError || previewError || isSlotError
    },
    fieldsAssociated () {
      return this.fields.reduce((fields, field) => {
        const { value } = field
        fields[value] = field
        return fields
      }, {})
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
        return await new Promise((resolve) => {
          Papa.parse(line, {
            ...this.config,
            ...{
              header: false, // overload, header is handled locally
              complete: (result) => {
                const { data: { 0: data } = {}, errors, meta } = result
                if (data) {
                  this.previewColumnCount = Math.max(this.previewColumnCount, data.length)
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
    resetPage () {
      this.lines = []
      this.preview = []
      this.previewColumnCount = 0
      this.setPage(1)
    },
    setPage (page) {
      this.page = page
      this.loadPage(page)
    },
    addPageColumn () {
      const { page, perPage } = this
      const firstLine = (page * perPage) - perPage
      this.page = (firstLine + perPage + 1) / (perPage + 1)
      this.perPage++
    },
    deletePageColumn () {
      const { page, perPage } = this
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
        const { $refs: { [key]: { 0: { focus } = {} } = {} } = {} } = this
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
    isComponentType (componentTypes, { key }) {
      if (key) {
        const index = this.fields.findIndex(field => field.value === key)
        if (index >= 0) {
          const fieldTypeComponents = this.fields[index].types.map(type => fieldTypeComponent[type])
          for (let t = 0; t < componentTypes.length; t++) {
            if (fieldTypeComponents.includes(componentTypes[t])) return true
          }
        }
      }
      return false
    },
    getStaticMappingOptions ({ key }) {
      let options = []
      if (key) {
        const index = this.fields.findIndex(field => field.value === key)
        if (index >= 0) {
          const field = this.fields[index]
          for (const type of field.types) {
            if (type in fieldTypeValues) {
              options.push(...fieldTypeValues[type](this))
            }
          }
        }
      }
      return options
    },
    getStaticMappingState (index) {
      const { $v: { staticMapping: { [index]: { value: { $invalid = false } = {} } = {} } = {} } = {} } = this
      return ($invalid) ? false : null
    },
    getStaticMappingInvalidFeedback (index, separator = ' ') {
      const { $v: { staticMapping: { [index]: { value: $v } = {} } = {} } = {} } = this
      let feedback = []
      if ('$params' in $v) {
        for (let validation of Object.keys($v.$params)) {
          if (!$v[validation]) feedback.push(validation)
        }
      }
      return feedback.join(separator).trim()
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
    importStart (dryRun = false) {
      this.importProgress.dryRun = dryRun

      const staticMapping = this.staticMapping.reduce((staticMapping, { key, value }) => {
        staticMapping[key] = value
        return staticMapping
      }, {})

      const parseLines = async (start, length) => {
        return new Promise((resolve) => {
          this.importProgress.status = this.$i18n.t('Reading file')
          this.readLines(start, length + 1).then(async (lines) => { // lookahead (+1 line) for pagination
            resolve(await Promise.all(
              lines.filter((line, index) => {
                if (line !== undefined) { // !EOF
                  this.linesCount = Math.max(this.linesCount, start + index + 1)
                  if (index < length) { // skip lookahead (+1 line)
                    return true
                  }
                }
                return false
              }).map(async (line) => {
                return new Promise((resolve) => {
                  this.importProgress.status = this.$i18n.t('Parsing file')
                  Papa.parse(line, {
                    ...this.config,
                    ...{
                      header: false, // overload, header is handled locally
                      complete: (result) => {
                        const { data: { 0: data } = {}, errors } = result
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

      const importLines = async (start, length) => {
        await parseLines(start, length).then(async (lines) => {
          const items = lines.reduce((items, { data }) => {
            if (data) {
              items.push({
                ...data.reduce((line, value, index) => {
                  if (this.importMapping[index]) {
                    const { fieldsAssociated: { [this.importMapping[index]]: { formatter } = {} } = {} } = this
                    if (formatter) {
                      line[this.importMapping[index]] = formatter(value)
                    }
                    else {
                      line[this.importMapping[index]] = value
                    }
                  }
                  return line
                }, {}),
                ...staticMapping
              })
            }
            return items
          }, [])
          const { config: { stopOnFirstError, ignoreUpdateIfExists, ignoreInsertIfNotExists } = {} } = this
          const payload = {
            items,
            stopOnFirstError,
            ignoreInsertIfNotExists: ignoreInsertIfNotExists || dryRun,
            ignoreUpdateIfExists: ignoreUpdateIfExists || dryRun
          }
          this.importProgress.done = items.length < length

          // eslint-disable-next-line no-async-promise-executor
          await new Promise(async (resolve, reject) => {
            if (!this.importProgress.exit) this.importProgress.status = this.$i18n.t('Sending data')
            this.importProgress.promise = { resolve, reject } // stash promise
            await this.importPromise(payload, dryRun, this.importProgress.done).then((result) => {
              if (!this.importProgress.exit) this.importProgress.status = this.$i18n.t('Processing response')
              if (result.constructor === Array && result.length > 0) {
                for (const line of result) {
                  const { isNew, item, errors, status } = line
                  this.importProgress.lastLine++
                  if (errors) {
                    this.importProgress.lastError = {
                      line: this.importProgress.lastLine,
                      errors: errors.map(error => {
                        const { field: key, message } = error
                        return {
                          key,
                          field: this.fields.find(field => field.value === key).text,
                          message,
                          value: item[key]
                        }
                      })
                    }
                    this.importProgress.errorCount++
                    if (stopOnFirstError) {
                      return // pause processing
                    }
                  } else {
                    this.importProgress.lastError = false
                    if (!dryRun && [404, 409].includes(status)) {
                      this.importProgress.skipCount++
                    } else if (isNew) {
                      this.importProgress.insertCount++
                    } else {
                      this.importProgress.updateCount++
                    }
                  }
                }
                resolve() // continue processing
              }
              reject() // stop processing
            }).catch((err) => {
              reject(err) // stop processing
            })
            this.$bvModal.show(`importProgress-${this.uuid}`) // re-open modal in case parent squashed it
          })
        })
      }

      const importStart = async (dryRun) => {
        const { config: { header, chunkSize: length } = {} } = this
        this.isImporting = true
        this.config.stopOnFirstError = true
        this.$set(this, 'importProgress', { // reset counters
          status: this.$i18n.t('Initializing'),
          insertCount: 0,
          updateCount: 0,
          skipCount: ((header) ? 1 : 0),
          errorCount: 0,
          lastError: false,
          lastLine: ((header) ? 1 : 0),
          promise: false,
          done: false,
          exit: false,
          dryRun
        })
        this.$bvModal.show(`importProgress-${this.uuid}`)
        do {
          await importLines(this.importProgress.lastLine, length).catch(() => {
            this.importProgress.status = (this.importProgress.exit)
              ? (dryRun) ? this.$i18n.t('Dry run cancelled') : this.$i18n.t('Import cancelled')
              : (dryRun) ? this.$i18n.t('Dry run completed') : this.$i18n.t('Import completed')
            this.importProgress.exit = true
          })
        } while (this.linesCount > this.importProgress.lastLine && !this.importProgress.done && !this.importProgress.exit)
        this.isImporting = false
      }

      importStart(dryRun) // handle w/ asyncronous
    },
    importCancel () {
      this.importProgress.status = this.$i18n.t('Stopping')
      this.importProgress.exit = true
      this.importProgress.lastError = false
      this.importProgress.promise.reject() // stop processing
    },
    importClose () {
      this.$bvModal.hide(`importProgress-${this.uuid}`)
    },
    importSkipOne () {
      this.importProgress.lastError = false
      this.importProgress.promise.resolve() // continue processing
    },
    importSkipAll () {
      this.config.stopOnFirstError = false
      this.importProgress.lastError = false
      this.importProgress.promise.resolve() // continue processing
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
      handler () {
        this.loadPreview()
      }
    },
    'config.encoding': {
      handler (a, b) {
        if (a !== b) {
          this.$store.dispatch(`${this.file.storeName}/setEncoding`, a || 'utf-8')
          this.resetPage()
        }
      },
      immediate: true
    },
    'config.escapeChar': {
      handler () {
        this.loadPreview()
      }
    },
    'config.header': {
      handler () {
        this.loadPage()
      }
    },
    'config.newline': {
      handler (a, b) {
        if (a !== b) {
          this.$store.dispatch(`${this.file.storeName}/setNewLine`, a || '\n')
          this.resetPage()
        }
      },
      immediate: true
    },
    'config.quoteChar': {
      handler () {
        this.loadPreview()
      }
    },
    file: {
      handler () {
        this.setPage(1)
      },
      deep: true,
      immediate: true
    },
    lines: {
      handler () {
        this.loadPreview()
      }
    },
    perPage: {
      handler () {
        this.loadPage()
      }
    },
    previewColumnCount: {
      handler (a) {
        this.importMapping = new Array(a)
          .fill(null)
          .map((_, index) => (index in this.importMapping) ? this.importMapping[index] : null)
      }
    },
    importMapping: {
      handler () {
        this.$nextTick(() => {
          const { $v: { $anyDirty = false, $touch = () => {} } = {} } = this
          if ($anyDirty) {
            $touch()
          }
        })
      },
      deep: true
    },
    staticMapping: {
      handler () {
        this.$nextTick(() => {
          const { $v: { $anyDirty = false, $touch = () => {} } = {} } = this
          if ($anyDirty) {
            $touch()
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
    .col-overflow-hidden {
      overflow: hidden;
      text-overflow: ellipsis;
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
