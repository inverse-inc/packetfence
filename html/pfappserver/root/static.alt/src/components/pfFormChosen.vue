<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-chosen" :class="{ 'mb-0': !columnLabel, 'is-focus': focus, 'is-empty': !value, 'is-disabled': disabled }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input-group>
      <multiselect
        v-model="inputValue"
        v-bind="$attrs"
        v-on="forwardListeners"
        ref="input"
        :allow-empty="allowEmpty"
        :clear-on-select="clearOnSelect"
        :disabled="disabled"
        :group-values="groupValues"
        :id="id"
        :internal-search="internalSearch"
        :multiple="multiple"
        :label="label"
        :options="options"
        :options-limit="optionsLimit"
        :placeholder="placeholder"
        :preserve-search="preserveSearch"
        :searchable="searchable"
        :show-labels="false"
        :state="inputState"
        :track-by="trackBy"
        @search-change="onSearchChange($event)"
        @open="onFocus"
        @close="onBlur"
      >
        <template v-slot:noResult>
          <b-media class="text-secondary" md="auto">
            <template v-if="loading">
              <template v-slot:aside><icon name="circle-notch" spin scale="2" class="mt-1 ml-2"></icon></template>
              <strong>{{ $t('Loading results') }}</strong>
              <b-form-text class="font-weight-light">{{ $t('Please wait...') }}</b-form-text>
            </template>
            <template v-else>
              <template v-slot:aside><icon name="search" scale="2" class="mt-1 ml-2"></icon></template>
              <strong>{{ $t('No results') }}</strong>
              <b-form-text class="font-weight-light">{{ $t('Please refine your search.') }}</b-form-text>
            </template>
          </b-media>
        </template>
      </multiselect>
      <b-input-group-append v-if="readonly || disabled">
        <b-button class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'
import { createDebouncer } from 'promised-debounce'
import pfMixinForm from '@/components/pfMixinForms'

export default {
  name: 'pf-form-chosen',
  mixins: [
    pfMixinForm
  ],
  components: {
    Multiselect
  },
  props: {
    value: {
      default: null
    },
    clearOnSelect: {
      type: Boolean,
      default: false
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    },
    /* multiselect props */
    allowEmpty: {
      type: Boolean,
      default: true
    },
    // Add a proxy on our inputValue to modify set/get for simple external models.
    // https://github.com/shentao/vue-multiselect/issues/385#issuecomment-418881148
    collapseObject: {
      type: Boolean,
      default: true
    },
    disabled: {
      type: Boolean,
      default: false
    },
    groupValues: {
      type: String
    },
    id: {
      type: String
    },
    internalSearch: {
      type: Boolean,
      default: true
    },
    label: {
      type: String,
      default: 'text'
    },
    loading: {
      type: Boolean,
      default: false
    },
    multiple: {
      type: Boolean,
      default: false
    },
    options: {
      type: Array,
      default: () => { return [] }
    },
    optionsLimit: {
      type: Number,
      default: 100
    },
    optionsSearchFunction: {
      type: Function
    },
    optionsSearchFunctionInitialized: { // true after first `optionsSearchFunction` call (for preloading)
      type: Boolean,
      default: false
    },
    placeholder: {
      type: String,
      default: null
    },
    preserveSearch: {
      type: Boolean,
      default: false
    },
    searchable: {
      type: Boolean,
      default: true
    },
    trackBy: {
      type: String,
      default: 'value'
    }
  },
  data () {
    return {
      focus: false
    }
  },
  computed: {
    inputValue: {
      get () {
        let currentValue
        if (this.formStoreName) {
          currentValue = this.formStoreValue || ((this.multiple) ? [] : null) // use FormStore
        } else {
          currentValue = this.value || ((this.multiple) ? [] : null) // use native (v-model)
        }
        if (this.collapseObject) {
          const options = (!this.groupValues)
            ? (this.options ? this.options : [])
            : this.options.reduce((options, group, index) => { // flatten group
              options.push(...group[this.groupValues])
              return options
            }, [])
          if (options.length === 0) { // no options
            return (this.multiple)
              ? [...new Set(currentValue.map(value => {
                return { [this.trackBy]: value, [this.label]: value }
              }))]
              : { [this.trackBy]: currentValue, [this.label]: currentValue }
          } else { // is options
            return (this.multiple)
              ? [...new Set(currentValue.map(value => {
                return options.find(option => option[this.trackBy] === value) || { [this.trackBy]: value, [this.label]: value }
              }))]
              : options.find(option => option[this.trackBy] === currentValue) || { [this.trackBy]: currentValue, [this.label]: currentValue }
          }
        }
        return currentValue
      },
      set (newValue) {
        if (this.collapseObject) {
          newValue = (this.multiple)
            ? [...new Set(newValue.map(value => value[this.trackBy]))]
            : (newValue && newValue[this.trackBy])
        }
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    onFocus (event) {
      this.focus = true
      this.onSearchChange(this.inputValue)
    },
    onBlur (event) {
      this.focus = false
      this.onSearchChange(this.inputValue)
    },
    onSearchChange (query) {
      if (this.optionsSearchFunction) {
        if (!this.$debouncer) {
          this.$debouncer = createDebouncer()
        }
        this.loading = true
        this.$debouncer({
          handler: () => {
            Promise.resolve(this.optionsSearchFunction(this, query)).then(options => {
              this.loading = false
              this.options = options
            }).catch(() => {
              this.loading = false
            }).finally(() => {
              this.optionsSearchFunctionInitialized = true
            })
          },
          time: 300
        })
      }
    }
  },
  watch: {
    value: {
      handler (a, b) {
        this.onSearchChange(a) // prime the searchable cache with our current `value`
      },
      immediate: true
    }
  }
}
</script>

<style lang="scss">
/* See styles/_form-chosen.scss */
</style>
