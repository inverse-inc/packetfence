<template>
  <b-form @submit.prevent="doImport()">

    <b-card-header header-tag="header" class="p-1 mt-3" role="tab">
      <b-btn block href="#" v-b-toggle="uuidStr('contents')" variant="light" class="text-left justify-content-md-center">
        <icon class="float-right when-opened my-1" name="chevron-down"></icon>
        <icon class="float-right when-closed my-1" name="chevron-right"></icon>
        <strong>{{ $t('CSV File Contents') }}</strong>
      </b-btn>
    </b-card-header>
    <b-collapse :id="uuidStr('contents')" :accordion="uuidStr()" role="tabpanel">
      <b-card-body>
        <b-form-textarea 
          :disabled="isLoading"
          class="line-numbers" size="sm" rows="1" max-rows="40"
          v-model="file.result"
          v-on:input="parse"
        ></b-form-textarea>
      </b-card-body>
    </b-collapse>

    <b-card-header header-tag="header" class="p-1 mt-3" role="tab">
      <b-btn block href="#" v-b-toggle="uuidStr('parser')" variant="light" class="text-left justify-content-md-center">
        <icon class="float-right when-opened my-1" name="chevron-down"></icon>
        <icon class="float-right when-closed my-1" name="chevron-right"></icon>
        <strong>{{ $t('CSV Parser Options') }}</strong>
      </b-btn>
    </b-card-header>
    <b-collapse :id="uuidStr('parser')" :accordion="uuidStr()" role="tabpanel">
      <b-card-body>
        <b-row>
          <b-col cols="6">
            <pf-form-input v-model="config.encoding" :label="$t('Encoding')" 
            :text="$t('The encoding to use when opening local files.')"/>
            <pf-form-input v-model="config.delimiter" :label="$t('Delimiter')" placeholder="auto" 
            :text="$t('The delimiting character. Leave blank to auto-detect from a list of most common delimiters.')"/>
            <pf-form-input v-model="config.newline" :label="$t('Newline')" placeholder="auto" 
            :text="$t('The newline sequence. Leave blank to auto-detect. Must be one of \\r, \\n, or \\r\\n.')"/>
            <b-form-group horizontal label-cols="3" :label="$t('Header')" class="my-1">
              <pf-form-toggle v-model="config.header" :color="{checked: '#28a745', unchecked: '#dc3545'}" :values="{checked: true, unchecked: false}">{{ (config.header) ? $t('Yes') : $t('No') }}</pf-form-toggle>
              <b-form-text>{{ $t('If enbabled, the first row of parsed data will be interpreted as field names.') }}</b-form-text>
            </b-form-group>
            <b-form-group horizontal label-cols="3" :label="$t('Skip Empty Lines')" class="my-1">
              <pf-form-toggle v-model="config.skipEmptyLines" :color="{checked: '#28a745', unchecked: '#dc3545'}" :values="{checked: true, unchecked: false}">{{ (config.skipEmptyLines) ? $t('Yes') : $t('No') }}</pf-form-toggle>
              <b-form-text>{{ $t('If true, lines that are completely empty (those which evaluate to an empty string) will be skipped.') }}</b-form-text>
            </b-form-group>
          </b-col>
          <b-col cols="6">
            <pf-form-input v-model="config.quoteChar" :label="$t('Quote Character')" 
            :text="$t('The character used to quote fields. The quoting of all fields is not mandatory. Any field which is not quoted will correctly read.')"/>
            <pf-form-input v-model="config.escapeChar" :label="$t('Escape Character')" 
            :text="$t('The character used to escape the quote character within a field. If not set, this option will default to the value of quoteChar, meaning that the default escaping of quote character within a quoted field is using the quote character two times.')"/>
            <pf-form-input v-model="config.comments" :label="$t('Comments')" 
            :text="$t('A string that indicates a comment (for example, \'#\' or \'//\').')"/>
            <pf-form-input v-model="config.preview" :label="$t('Preview')" 
            :text="$t('If > 0, only that many rows will be parsed.')"/>
          </b-col>
        </b-row>
      </b-card-body>
    </b-collapse>

    <b-card-header header-tag="header" class="p-1 mt-3" role="tab">
      <b-btn block href="#" v-b-toggle="uuidStr('table')" variant="light" class="text-left justify-content-md-center">
        <icon class="float-right when-opened my-1" name="chevron-down"></icon>
        <icon class="float-right when-closed my-1" name="chevron-right"></icon>
        <strong>{{ $t('Import Data') }}</strong>
      </b-btn>
    </b-card-header>
    <b-collapse :id="uuidStr('table')" :accordion="uuidStr()" role="tabpanel" visible>
      <b-card-body>
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
          show-empty responsive hover
        >
          <template slot="HEAD_actions" slot-scope="head">
            <input type="checkbox" id="checkallnone" v-model="selectAll" @change="onSelectAllChange" @click.stop>
            <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{$t('Select None [ALT+N]')}}</b-tooltip>
            <b-tooltip target="checkallnone" placement="right" v-else>{{$t('Select All [ALT+A]')}}</b-tooltip>
          </template>
          <template slot="actions" slot-scope="data">
            <input type="checkbox" :id="data.value" :value="data.item" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)">
            <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._rowMessage" v-b-tooltip.hover.right :title="tableValues[data.index]._rowMessage"></icon>
          </template>

          <template slot="top-row" slot-scope="data">
            <td v-for="column in data.columns" :class="['p-1', {'table-danger': !hasMappings() || column === 1 && !canImport() }]">
              <b-form-select v-if="column > 1" v-model="tableMapping[column - 2]" :options="selectMapping(column - 2)" />
            </td>
          </template>
          <template slot="bottom-row" slot-scope="data">
            <td :colspan="data.columns">
              <b-button type="submit" variant="primary" :disabled="!canImport()">
                <icon v-if="isLoading" name="circle-notch" spin class="mr-1"></icon> 
                <icon v-else name="download" class="mr-1"></icon> 
                {{ $t('Import') + ' ' + selectValues.length + ' ' + $t('selected rows') }}
              </b-button>
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
      </b-card-body>
    </b-collapse>

  </b-form>
</template>

<script>
import Papa from 'papaparse'
import uuidv4 from 'uuid/v4'
import pfFormInput from '@/components/pfFormInput'
import pfFormToggle from '@/components/pfFormToggle'
import pfMixinSelectable from '@/components/pfMixinSelectable'

export default {
  name: 'pf-csv-parse',
  components: {
    'pf-form-input': pfFormInput,
    'pf-form-toggle': pfFormToggle
  },
  mixins: [
    pfMixinSelectable
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
      uuid: uuidv4(),
      config: {
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
      sortDesc: false
    }
  },
  methods: {
    uuidStr (section) {
      return (section || 'default') + '-' + this.uuid
    },
    parse () {
      const _this = this
      Papa.parse(this.file.result, Object.assign({}, this.config, {
        complete (results) {
          _this.data = results.data
          _this.meta = results.meta
          console.log(['meta', results.meta])
          // setup placeholders in tableMapping Array
          _this.tableMapping = new Array(results.meta.fields.length).fill(null)
          // _this.$refs[_this.uuidStr('table')].refresh()
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
    selectMapping (index) {
      let fields = [
        { // ignore
          value: null,
          text: this.$i18n.t('Ignore Column')
        },
        { // seperator
          value: null,
          text: ' ',
          disabled: true
        }
      ]
      fields.push(...this.fields)
      fields.forEach((f, i, fs) => {
        if (!f.value) return // ignore null
        // disable fields selected elsewhere
        fields[i].disabled = this.tableMapping.map((field, _i) => { return (_i === index) ? null : field }).includes(f.value)
      })
      return fields
    },
    canImport () {
      return (this.hasMappings() && this.hasSelection())
    },
    hasMappings () {
      // is every required fields mapped?
      return this.fields.filter(field => field.required).every((field, index, fields) => {
        // does tableMapping include required field?
        return this.tableMapping.includes(field.value)
      })
    },
    hasSelection () {
      // are 1+ rows selected?
      return (this.selectValues.length > 0)
    },
    doImport (event) {
      const cheatSheet = this.tableMapping.reduce((accumulator, field, index) => {
        if (field !== null) accumulator[this.meta.fields[index]] = field
        return accumulator
      }, {})
      const mappedValues = this.selectValues.reduce((accumulator, value) => {
        const mappedValue = Object.keys(value).reduce((accumulatorB, key) => {
          if (cheatSheet[key]) accumulatorB[cheatSheet[key]] = value[key]
          return accumulatorB
        }, {})
        accumulator.push(mappedValue)
        return accumulator
      }, [])
      this.$emit('input', mappedValues, this.selectValues)
    }
  },
  computed: {
    items () {
      return this.data || []
    },
    columns () {
      const columns = [{
        key: 'actions',
        label: this.$i18n.t('Actions'),
        sortable: false,
        visible: true,
        locked: true,
        variant: (this.hasSelection()) ? '' : 'danger'
      }] // for pfMixinSelectable
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
        this.parse()
      },
      deep: true
    }
  },
  mounted () {
    this.parse()
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
    background: url(data:image/png;base64,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) no-repeat 0px 0px;
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
</style>
