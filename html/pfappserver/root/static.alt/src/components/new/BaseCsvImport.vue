<template>
  <b-form @submit.prevent="doExport()">
    <b-card no-body ref="rootRef">
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
          <div class="base-csv-import-table" :class="{ 'hover': hover, 'striped': striped }">
            <!-- table head -->
            <b-row class="base-csv-import-table-head">
              <b-col class="text-nowrap">
                {{ $t('Field Mappings') }}
              </b-col>
              <template v-for="(_, colIndex) in new Array(perPage)">
                <b-col class="text-nowrap" :key="`col-${colIndex}`">
                  <template v-if="((perPage * page) - perPage + colIndex + 1) <= (linesCount - ((parseConfig.header) ? 1 : 0))">
                    {{ $t('Line') }} #{{ (perPage * page) - perPage + colIndex + 1 }}
                  </template>
                  <template v-else>
                    <icon name="ban" class="text-secondary"/>
                  </template>
                </b-col>
              </template>
            </b-row>
<pre>{{ {importMappingInvalidFeedback, importMappingState} }}</pre>              
            
            <!-- table body -->
            <b-row class="base-csv-import-table-row" v-for="(_, rowIndex) in previewColumnCount" :key="`row-${rowIndex}`">
              <b-col>
<!--
                <b-form-group
                  :state="($v && 'importMapping' in $v && $v.importMapping.$invalid) ? false : null"
                  :invalid-feedback="getImportMappingVuelidateFeedback()"
                  class="my-1 base-csv-import-form-group"
                >
-->                
                <b-form-group
                  :state="!reservedMappingInvalidFeedback"
                  :invalid-feedback="reservedMappingInvalidFeedback"
                  class="my-1 base-csv-import-form-group"
                >
                  <b-input-group>
                    <template v-slot:append v-if="importMapping[rowIndex]">
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
                  <template v-if="importMappingState[colIndex][rowIndex] === false">
                    <!-- invalid -->
                    <icon name="exclamation-circle" class="text-danger mr-1"/> {{ getPreview(colIndex, rowIndex) }}
                    <div class="is-invalid invalid-feedback d-block">
                      {{ importMappingInvalidFeedback[colIndex][rowIndex] }}
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
            <b-row class="base-csv-import-table-row" v-for="(staticMap, index) in staticMapping" :key="index">
              <b-col>
                <b-input-group>
                  <template v-slot:append>
                    <b-button @click="deleteStaticMapping(index)" variant="light" class="text-secondary pb-1" v-b-tooltip.hover.left.d300 :title="$t('Delete static field')"><icon name="times-circle"/></b-button>
                  </template>
                  <b-form-select v-model="staticMap.key" :options="staticMappingOptions" :disabled="isDisabled" @change="focusStaticMapping(staticMap.key)"></b-form-select>
                </b-input-group>
              </b-col>
              <b-col>
                <component :is="staticMappingComponentIs[index]"
                  v-bind="staticMappingComponentProps[index]"
                  v-model="staticMap.value"
                  :validator="staticMappingComponentValidator[index]"
                />
              </b-col>
              <b-col v-for="(_) in new Array(perPage - 1)" :key="_">-</b-col>
            </b-row>
            <b-row class="base-csv-import-table-row" v-if="staticMappingOptions.filter(f => f.value && !f.disabled).length > 0">
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
      <b-card-footer v-if="previewColumnCount > 0">
        <b-button variant="primary" class="mr-1" :disabled="isDisabled || !isMappingValid" @click="importStart(false)">
          <icon v-if="isImporting && !importProgress.dryRun" name="circle-notch" spin class="mr-1"></icon>
          <icon v-else name="download" class="mr-1"></icon>
          {{ $t('Import') }}
        </b-button>
        <b-button variant="outline-primary" class="mr-1" :disabled="isDisabled || !isMappingValid" @click="importStart(true)">
          <icon v-if="isImporting && importProgress.dryRun" name="circle-notch" spin class="mr-1"></icon>
          <icon v-else name="long-arrow-alt-down" class="mr-1"></icon>
          {{ $t('Dry Run') }}
        </b-button>
        <b-button variant="link" class="mr-1" :disabled="isDisabled" v-b-modal="`importOptions-${uuid}`">Import Options</b-button>
        <span v-if="!isMappingValid" class="ml-2">
          <icon name="exclamation-circle" class="text-danger mr-1"/>
          <span class="invalid-feedback d-inline" v-t="'Fix all errors before importing.'"></span>
        </span>
      </b-card-footer>
    </b-card>

    <b-modal :id="`parserOptions-${uuid}`" size="lg" centered :title="$t('Parsing Options')">
      <base-form-group-chosen-one v-model="parseConfig.encoding" 
        :column-label="$t('Encoding')" 
        :disabled="isDisabled"
        :options="encoding.map(enc => { return { text: enc, value: enc } })"
        :text="$t('The encoding to use when opening local files.')"
      />
      <base-form-group-toggle-false-true v-model="parseConfig.header" 
        :column-label="$t('Header')" 
        :disabled="isDisabled"
        :text="$t('If enabled, the first row of parsed data will be interpreted as field names.')"
      />
      <base-form-group-input v-model="parseConfig.delimiter" 
        :column-label="$t('Delimiter')" 
        placeholder="auto" 
        :disabled="isDisabled"
        :text="$t('The delimiting character. Leave blank to auto-detect from a list of most common delimiters.')"
      />
      <base-form-group-input v-model="parseConfig.newline" 
        :column-label="$t('Newline')" 
        placeholder="auto" 
        :disabled="isDisabled"
        :text="$t('The newline sequence. Leave blank to auto-detect. Must be one of \\r, \\n, or \\r\\n.')"
      />
      <base-form-group-input v-model="parseConfig.quoteChar" 
        :column-label="$t('Quote Character')" 
        :disabled="isDisabled"
        :text="$t('The character used to quote fields. The quoting of all fields is not mandatory. Any field which is not quoted will correctly read.')"
      />
      <base-form-group-input v-model="parseConfig.escapeChar" 
        :column-label="$t('Escape Character')" 
        :disabled="isDisabled"
        :text="$t('The character used to escape the quote character within a field. If not set, this option will default to the value of quoteChar, meaning that the default escaping of quote character within a quoted field is using the quote character two times.')"
      />
      <template v-slot:modal-footer>
        <b-button variant="primary" @click="$bvModal.hide(`parserOptions-${uuid}`)">{{ $t('Continue') }}</b-button>
      </template>
    </b-modal>

    <b-modal :id="`importOptions-${uuid}`" size="lg" centered :title="$t('Import Options')">
      <base-form-group-toggle-false-true v-model="importConfig.ignoreInsertIfNotExists" 
        :column-label="$t('Insert new')" 
        :disabled="isDisabled"
        :text="$t('If enabled, items that do not currently exist are created.')"
      />
      <base-form-group-toggle-false-true v-model="importConfig.ignoreUpdateIfExists" 
        :column-label="$t('Update exists')" 
        :disabled="isDisabled"
        :text="$t('If enabled, items that currently exist are overwritten.')"
      />
      <base-form-group-chosen-one v-model="importConfig.chunkSize" 
        :column-label="$t('API chunk size')" 
        :disabled="isDisabled"
        :options="[10, 50, 100, 500, 1000].map(i => { return { value: i, text: i } })"
        :text="$t('The number of items imported with each API request. Higher numbers are faster but consume more memory with large files.')"
      />
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
                  <template v-if="importProgress.dryRun || importConfig.ignoreInsertIfNotExists" size="lg">
                    {{ importProgress.insertCount }} <icon name="lock" class="ml-1"/>
                  </template>
                  <template v-else>{{ importProgress.insertCount }}</template>
                </b-col>
              </b-row>
              <b-row align-v="center">
                <b-col cols="10">{{ $t('Updated') }} <em v-if="importProgress.dryRun">({{ $t('not commited') }})</em></b-col>
                <b-col cols="2" class="text-right">
                  <template v-if="importProgress.dryRun || importConfig.ignoreUpdateIfExists">
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
          <b-button v-if="importProgress.dryRun" variant="primary" class="mr-1" :disabled="isDisabled || !isMappingValid" @click="importStart(false)">
            <icon name="download" class="mr-1"></icon>
            {{ $t('Import') }}
          </b-button>
          <b-button variant="primary" @click="$bvModal.hide(`importProgress-${uuid}`)" class="ml-1">{{ $t('Close') }}</b-button>
        </template>
      </template>
    </b-modal>
  </b-form>
</template>

<script>
import Papa from 'papaparse'
import BaseFormGroupChosenOne from './BaseFormGroupChosenOne'
import BaseFormGroupInput from './BaseFormGroupInput'
import BaseFormGroupToggleFalseTrue from './BaseFormGroupToggleFalseTrue'
import {
  pfFieldTypeValues as fieldTypeValues,
  useField
} from '@/globals/pfField'

const components = {
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupToggleFalseTrue
}

const props = {
  file: {
    type: Object
  },
  fields: {
    type: Array,
    default: () => ([])
  },
  defaultStaticMapping: {
    type: Array,
    default: () => ([])
  },
  hover: {
    type: Boolean
  },
  striped: {
    type: Boolean
  },
  isLoading: {
    type: Boolean
  },
  isSlotError: {
    type: Boolean
  },
  importPromise: {
    type: Function,
    default: () => {}
  }  
}

import { computed, nextTick, reactive, ref, set, toRefs, watch } from '@vue/composition-api'
import { useQuerySelectorAll } from '@/composables/useDom'
import bytes from '@/utils/bytes'
import encoding from '@/utils/encoding'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const setup = (props, context) => {
  
  const {
    defaultStaticMapping,
    file,
    fields,
    importPromise,
    isLoading
  } = toRefs(props)
  
  const { refs, root: { $store } = {} } = context
  
  // template ref (for Mutation Observers)
  const rootRef = ref(null)
  
  // Papa parse config
  const parseConfig = ref({
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
  })
  
  // Import config
  const importConfig = ref({
    chunkSize: 100,
    stopOnFirstError: true,
    ignoreUpdateIfExists: false,
    ignoreInsertIfNotExists: false
  })
  
  const uuid = computed(() => {
    const { name, lastModified } = file.value
    return `${name}-${lastModified}`    
  })
  
  // associate props.field to avoid iterative lookups
  const _fieldsAssociated = computed(() => {
    return fields.value.reduce((fields, field) => {
      const { value } = field
      fields[value] = field
      return fields
    }, {})
  })
  
   // lines from `file`
  const lines = ref([])
  
  // maximum number of lines from `lines`
  const linesCount = ref(0)
   
   // parsed from `lines`
  const preview = ref([])
  
  // maximum number of columns from `preview`
  const previewColumnCount = ref(0)
  
  // current page number
  const page = ref(1)
  
  // lines per page
  const perPage = ref(3)

  // user selection(s) for import mappings
  const importMapping = ref([])
  const _importMappingSchema = computed(() => importMapping.value.map((field) => {
    const { validator } = _fieldsAssociated.value[field] || {}
    return (validator)
      ? validator
      : yup.string().nullable()
  }))
  const importMappingOptions = computed(() => {
    return fields.value
      .map(field => {
        return { ...field, ...{ disabled: field.value && reservedMapping.value.includes(field.value) } } // disable if reserved
      })
  })
  const importMappingInvalidFeedback = reactive({})
  const importMappingState = reactive({})
  watch([_importMappingSchema, preview], () => {
    new Array(perPage.value)
      .fill(null)
      .map((_, colIndex) => {
        const { [colIndex]: { data = [] } = {} } = preview.value
        set(importMappingInvalidFeedback, colIndex, new Array(data.length).fill(null)) // null fill
        set(importMappingState, colIndex, new Array(data.length).fill(true)) // true fill
        return data.map((value, rowIndex) => {
          _importMappingSchema.value[rowIndex].validate(value)
            .catch((ValidationError) => {
              const { message } = ValidationError
              set(importMappingInvalidFeedback[colIndex], rowIndex, message)
              set(importMappingState[colIndex], rowIndex, false)
            })
        })
      })
  }, { deep: true, immediate: true })
  const deleteImportMapping = (index) => {
    set(importMapping.value, index, null)
  }
   
  // user selection(s) for static mappings
  const staticMapping = ref(defaultStaticMapping.value)
  const staticMappingSelect = ref(null)
  const staticMappingOptions = computed(() => {
    return fields.value
      .filter(field => !field.required) // don't include required fields
      .map(field => {
        return { ...field, ...{ disabled: field.value && reservedMapping.value.includes(field.value) } } // disable if reserved
      })
  })
  const _staticMappingField = computed(() => {
    return staticMapping.value
      .map(staticMap => useField(_fieldsAssociated.value[staticMap.key]))
  })
  const staticMappingComponentIs = computed(() => _staticMappingField.value.map(({ is }) => is))
  const staticMappingComponentProps = computed(() => _staticMappingField.value.map(({ is, validator, ...props }) => props))
  const addStaticMapping = () => {
    const key = staticMappingSelect.value
    if (reservedMapping.value.includes(key)) 
      return
    staticMapping.value.push({ key, value: null })
    focusStaticMapping(key)
    staticMappingSelect.value = null
  }
  const staticMappingComponentValidator = computed(() => staticMapping.value
    .map(staticMap => {
      const { validator } = _fieldsAssociated.value[staticMap.key]
      return validator // field validator
        .concat(yup.string().nullable().required(i18n.t('Value required.'))) // always required
    })
  )
  const deleteStaticMapping = (index) => {
    staticMapping.value.splice(index, 1)
  }
   
  const reservedMapping = computed(() => {
    return [ ...importMapping.value.filter(field => field), ...staticMapping.value.map(field => field.key) ]
  })
  const reservedMappingInvalidFeedback = computed(() => {
    const invalidFeedback = []
    if (importMapping.value.filter(r => r).length === 0)
      invalidFeedback.push(i18n.t('Map at least 1 column.'))
    if (fields.value.filter(field => field.required && !importMapping.value.includes(field.value)).length > 0)
      invalidFeedback.push(i18n.t('Missing required fields.'))
    return invalidFeedback.join(' ')
  })
    
  const _invalidNodes = useQuerySelectorAll(rootRef, '.is-invalid')
  const isMappingValid = computed(() => (!_invalidNodes.value || Array.prototype.slice.call(_invalidNodes.value).length === 0))  
  
  const isImporting = ref(false)

  const importProgress = ref({
    status: i18n.t('Idle'),
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
  })
  
  const pageMax = computed(() => {
    const { header } = parseConfig.value
    return Math.ceil((linesCount.value - ((header) ? 1 : 0)) / perPage.value)
  })
  
  const isDisabled = computed(() => isLoading.value || isImporting.value)
  
  const readLines = (start, length) => {
    const _readLines = async (start, length) => {
      let lines = []
      let line
      for (let l = start; l < start + length; l++) {
        line = await $store.dispatch(`${file.value.storeName}/readLine`, l).then(line => line)
        lines.push(line)
      }
      return lines
    }
    return _readLines(start, length)
  }
  
  const loadPreview = () => {
    const _parseLine = async (line) => {
      return await new Promise((resolve) => {
        Papa.parse(line, {
          ...parseConfig.value,
          ...{
            header: false, // overload, header is handled locally
            complete: (result) => {
              const { data: { 0: data } = {}, errors, meta } = result
              if (data)
                previewColumnCount.value = data.length
              return resolve({ data, errors, meta })
            }
          }
        })
      })
    }
    const _loadPreview = async (lines) => {
      let preview = []
      for (let line of lines) {
        preview.push(await _parseLine(line))
      }
      return preview
    }
    _loadPreview(lines.value).then(_preview => {
      preview.value = _preview
    })
  }
  
  const loadPage = (_page) => {
    page.value = _page || page.value
    const length = perPage.value
    const offset = (parseConfig.value.header) ? 1 : 0 // skip header
    const start = ((page.value - 1) * length) + offset
    readLines(start, length + 1).then(_lines => { // lookahead (+1 line) for pagination
      lines.value = _lines.filter((line, index) => {
        if (line !== undefined) { // !EOF
          linesCount.value = Math.max(linesCount.value, start + index + 1)
          if (index < length) // skip lookahead (+1 line)
            return true
        }
        return false
      })
    })
  }
  
  const resetPage = () => {
    lines.value = []
    preview.value = []
    previewColumnCount.value = 0
    setPage(1)
  }
  
  const setPage = (_page) => {
    page.value = _page
    loadPage(_page)
  }
  
  const addPageColumn = () => {
    const firstLine = (page.value * perPage.value) - perPage.value
    page.value = (firstLine + perPage.value + 1) / (perPage.value + 1)
    perPage.value++
  }
  
  const deletePageColumn = () => {
    const firstLine = (page.value * perPage.value) - perPage.value
    page.value = (firstLine + perPage.value - 1) / (perPage.value - 1)
    perPage.value--
  }
  
  const focusStaticMapping = (key) => {
    nextTick(() => {
      const { [key]: { 0: { focus } = {} } = {} } = refs
      if (focus)
        focus()
    })
  }
  
  const getStaticMappingOptions = ({ key }) => {
    let options = []
    if (key) {
      const index = fields.value.findIndex(field => field.value === key)
      if (index >= 0) {
        const field = fields.value[index]
        for (const type of field.types) {
          if (type in fieldTypeValues)
            options.push(...fieldTypeValues[type]())
        }
      }
    }
    return options
  }
  
  // safe accessor
  const getPreview = (colIndex, rowIndex) => {
    const { [colIndex]: { data: { [rowIndex]: _preview = null } = {} } = {} } = preview.value
    return _preview
  }

  const importStart = (dryRun = false) => {
    importProgress.value.dryRun = dryRun
    const _staticMapping = staticMapping.value.reduce((staticMapping, { key, value }) => {
      staticMapping[key] = value
      return staticMapping
    }, {})
    const _parseLines = async (start, length) => {
      return new Promise((resolve) => {
        importProgress.value.status = i18n.t('Reading file')
        readLines(start, length + 1)
          .then(async (lines) => { // lookahead (+1 line) for pagination
            resolve(await Promise.all(
              lines
                .filter((line, index) => {
                  if (line !== undefined) { // !EOF
                    linesCount.value = Math.max(linesCount.value, start + index + 1)
                    if (index < length) // skip lookahead (+1 line)
                      return true
                  }
                  return false
                })
                .map(async (line) => {
                  return new Promise((resolve) => {
                    importProgress.value.status = i18n.t('Parsing file')
                    Papa.parse(line, {
                      ...parseConfig.value,
                      header: false, // overload, header is handled locally
                      complete: (result) => {
                        const { data: { 0: data } = {}, errors } = result
                        resolve({ data, errors })
                      }
                    })
                  })
                })
            ))
          })
      })
    }
    const _importLines = async (start, length) => {
      await _parseLines(start, length).then(async (lines) => {
        const items = lines.reduce((items, { data }) => {
          if (data) {
            items.push({
              ...data.reduce((line, value, index) => {
                if (importMapping.value[index]) {
                  const { [importMapping.value[index]]: { formatter } = {} } = _fieldsAssociated.value
                  if (formatter)
                    line[importMapping.value[index]] = formatter(value)
                  else
                    line[importMapping.value[index]] = value
                }
                return line
              }, {}),
              ..._staticMapping
            })
          }
          return items
        }, [])
        const { stopOnFirstError, ignoreUpdateIfExists, ignoreInsertIfNotExists } = importConfig.value
        const payload = {
          items,
          stopOnFirstError,
          ignoreInsertIfNotExists: ignoreInsertIfNotExists || dryRun,
          ignoreUpdateIfExists: ignoreUpdateIfExists || dryRun
        }
        importProgress.value.done = items.length < length
        // eslint-disable-next-line no-async-promise-executor
        await new Promise(async (resolve, reject) => {
          if (!importProgress.value.exit) 
            importProgress.value.status = i18n.t('Sending data')
          importProgress.value.promise = { resolve, reject } // stash promise
          await importPromise.value(payload, dryRun, importProgress.value.done)
            .then((result) => {
              if (!importProgress.value.exit) 
                importProgress.value.status = i18n.t('Processing response')
              if (result.constructor === Array && result.length > 0) {
                for (const line of result) {
                  const { isNew, item, errors, status } = line
                  importProgress.value.lastLine++
                  if (errors) {
                    importProgress.value.lastError = {
                      line: importProgress.value.lastLine,
                      errors: errors.map(error => {
                        const { field: key, message } = error
                        return {
                          key,
                          field: fields.value.find(field => field.value === key).text,
                          message,
                          value: item[key]
                        }
                      })
                    }
                    importProgress.value.errorCount++
                    if (stopOnFirstError)
                      return // pause processing
                  } else {
                    importProgress.value.lastError = false
                    if (!dryRun && [404, 409].includes(status))
                      importProgress.value.skipCount++
                    else if (isNew)
                      importProgress.value.insertCount++
                    else
                      importProgress.value.updateCount++
                  }
                }
                resolve() // continue processing
              }
              reject() // stop processing
            })
            .catch((err) => reject(err)) // stop processing
// TODO            
// this.$bvModal.show(`importProgress-${this.uuid}`) // re-open modal in case parent squashed it
        })
      })
    }

    const _importStart = async (dryRun) => {
      const { header } = parseConfig.value
      const { chunkSize: length } = importConfig.value
      isImporting.value = true
      importConfig.value.stopOnFirstError = true
      importProgress.value = { // reset counters
        status: i18n.t('Initializing'),
        insertCount: 0,
        updateCount: 0,
        skipCount: (header) ? 1 : 0,
        errorCount: 0,
        lastError: false,
        lastLine: (header) ? 1 : 0,
        promise: false,
        done: false,
        exit: false,
        dryRun
      }
// TODO      
// this.$bvModal.show(`importProgress-${this.uuid}`)
      do {
        await _importLines(importProgress.value.lastLine, length)
          .catch(() => {
            importProgress.value.status = (importProgress.value.exit)
              ? (dryRun) ? i18n.t('Dry run cancelled') : i18n.t('Import cancelled')
              : (dryRun) ? i18n.t('Dry run completed') : i18n.t('Import completed')
            importProgress.value.exit = true
          })
      } while (linesCount.value > importProgress.value.lastLine && !importProgress.value.done && !importProgress.value.exit)
      isImporting.value = false
    }

    _importStart(dryRun) // handle w/ asyncronous
  }
 
  const importCancel = () => {
    importProgress.value.status = i18n.t('Stopping')
    importProgress.value.exit = true
    importProgress.value.lastError = false
    importProgress.value.promise.reject() // stop processing
  }
  
  const importSkipOne = () => {
    importProgress.value.lastError = false
    importProgress.value.promise.resolve() // continue processing
  }
  
  const importSkipAll = () => {
    importConfig.value.stopOnFirstError = false
    importProgress.value.lastError = false
    importProgress.value.promise.resolve() // continue processing
  } 
  
  watch([
    () => parseConfig.value.header,
    perPage
  ], () => loadPage(), { immediate: true })
  
  watch([
    () => parseConfig.value.delimiter,
    () => parseConfig.value.escapeChar,
    () => parseConfig.value.quoteChar,
    lines
  ], () => loadPreview())
  
  watch(file, () => setPage(1), { deep: true, immediate: true })
  
  watch(() => parseConfig.value.encoding, (a, b) => {
    if (a !== b) {
      $store.dispatch(`${file.value.storeName}/setEncoding`, a || 'utf-8')
      resetPage()
    }
  }, { immediate: true })
  
  watch(() => parseConfig.value.newline, (a, b) => {
    if (a !== b) {
      $store.dispatch(`${file.value.storeName}/setNewLine`, a || '\n')
      resetPage()
    }
  }, { immediate: true })

  watch(previewColumnCount, (a) => {
    importMapping.value = new Array(a)
      .fill(null)
      .map((_, index) => (index in importMapping.value) ? importMapping.value[index] : null)
  })

  return {
    bytes,
    encoding,
    
    rootRef,
    parseConfig,
    importConfig,
    uuid,
    
    page,
    perPage,
    pageMax,
    isDisabled,
    linesCount,
    previewColumnCount,
    
    importMapping,
    importMappingOptions,
    importMappingInvalidFeedback,
    importMappingState,
    deleteImportMapping,
    staticMapping,
    staticMappingSelect,
    staticMappingOptions,
    staticMappingComponentIs, 
    staticMappingComponentProps,
    staticMappingComponentValidator,
    addStaticMapping,
    deleteStaticMapping,
    focusStaticMapping,
    reservedMapping,
    reservedMappingInvalidFeedback,
    isMappingValid,
  
    setPage,
    addPageColumn,
    deletePageColumn,
    getStaticMappingOptions,
    getPreview,
    
    isImporting,
    importProgress,
    importStart,
    importCancel,
    importSkipOne,
    importSkipAll    
  }
}

// @vue/component
export default {
  name: 'base-csv-import',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

<style lang="scss">
.base-csv-import-table {
  color: #495057;
  border-spacing: 2px;
  .base-csv-import-table-head {
    border-top: 1px solid #dee2e6;
    border-bottom: 2px solid #dee2e6;
    font-weight: bold;
    vertical-align: middle;
    & > div {
      vertical-align: bottom;
    }
  }
  .base-csv-import-table-row {
    border-top: 1px solid #dee2e6;
    cursor: pointer;
  }
  .base-csv-import-table-head,
  .base-csv-import-table-row {
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
    .base-csv-import-table-row {
      &:nth-of-type(odd) {
        background-color: rgba(0,0,0,.05);
      }
    }
  }
  &.hover {
    .base-csv-import-table-row {
      &:hover {
        background-color: rgba(0,0,0,.075);
        color: #495057;
      }
    }
  }
  .base-csv-import-form-group {
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
