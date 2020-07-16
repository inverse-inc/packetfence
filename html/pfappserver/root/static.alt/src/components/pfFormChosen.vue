<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-chosen" :class="{ 'mb-0': !columnLabel, 'is-focus': isFocus, 'is-empty': !inputValue, 'is-disabled': disabled, [`pf-form-chosen-${size}`]: size }">
    <template v-slot:invalid-feedback>
      {{ inputInvalidFeedback }}
    </template>
    <b-input-group>
      <multiselect ref="multiselect"
        v-model="multiselectValue"
        v-bind="$attrs"
        v-on="forwardListeners"
        :allow-empty="allowEmpty"
        :clear-on-select="clearOnSelect"
        :disabled="disabled"
        :group-label="groupLabel"
        :group-values="groupValues"
        :id="id"
        :internal-search="false"
        :multiple="multiple"
        :label="label"
        :options="multiselectOptions"
        :options-limit="optionsLimit"
        :placeholder="placeholder"
        :taggable="taggable"
        :tag-placeholder="multiselectTagPlaceholder"
        :preserve-search="preserveSearch"
        :searchable="searchable"
        :show-labels="false"
        :state="inputState"
        :track-by="trackBy"
        :size="size"
        @search-change="onSearchChange($event)"
        @open="onFocus"
        @close="onBlur"
        @tag="addTag"
      >
        <template v-slot:singleLabel="{ option }">
          {{ tagCache[option.value] || option.value }}
        </template>
        <template v-slot:tag="{ option }">
          <span class="multiselect__tag" :class="(isFocus && optionsList.includes(option.value)) ? 'bg-primary' : 'bg-secondary'">
            <span>{{ tagCache[option.value] || option.value }}</span>
            <i aria-hidden="true" tabindex="1" class="multiselect__tag-icon" @click="removeTag(option.value)"></i>
          </span>
        </template>
        <template v-slot:beforeList v-if="internalSearch || optionsSearchFunction">
          <li class="multiselect__element" v-if="internalSearch">
            <div class="col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">{{ $t('Type to filter results') }}</div>
          </li>
          <li class="multiselect__element" v-if="optionsSearchFunction">
            <div class="col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">{{ $t('Type to search results') }}</div>
          </li>
        </template>
        <template v-slot:noResult>
          <template v-if="isLoading">
            <b-media class="text-secondary" md="auto">
              <template v-slot:aside><icon name="circle-notch" spin scale="1.5" class="mt-2 ml-2"></icon></template>
              <strong>{{ $t('Loading results') }}</strong>
              <b-form-text class="font-weight-light">{{ $t('Please wait...') }}</b-form-text>
            </b-media>
          </template>
          <template v-else>
            <b-media class="text-secondary" md="auto">
              <template v-slot:aside><icon name="search" scale="1.5" class="mt-2 ml-2"></icon></template>
              <strong>{{ $t('No results') }}</strong>
              <b-form-text class="font-weight-light">{{ $t('Please refine your search.') }}</b-form-text>
            </b-media>
          </template>
        </template>
      </multiselect>
      <b-input-group-append v-show="readonly || disabled" :size="size">
        <b-button :size="size" class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-show="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'
import { createDebouncer } from 'promised-debounce'
import pfMixinForm from '@/components/pfMixinForm'

const SEARCH_BY_ID = true
const SEARCH_BY_TEXT = false

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
      type: [String, Number],
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
    readonly: {
      type: Boolean,
      default: false
    },
    groupLabel: {
      type: String
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
    multiple: {
      type: Boolean,
      default: false
    },
    options: {
      type: Array,
      default: () => { return [] }
    },
    optionsLimit: {
      type: [String, Number],
      default: 100
    },
    optionsSearchFunction: {
      type: Function
    },
    placeholder: {
      type: String,
      default: null
    },
    taggable: {
      type: Boolean,
      default: false
    },
    tagPlaceholder: {
      type: String,
      default: null
    },
    preserveSearch: {
      type: Boolean,
      default: true
    },
    searchable: {
      type: Boolean,
      default: true
    },
    trackBy: {
      type: String,
      default: 'value'
    },
    size: {
      type: String,
      default: 'md'
    }
  },
  errorCaptured (err) { // capture exceptions from vue-multiselect component
    // eslint-disable-next-line
    console.error(err)
    return false // prevent error from propagating
  },
  data () {
    return {
      localOptions: [],
      isLoading: false,
      isFocus: false,
      internalSearchQuery: null,
      tagCache: {}
    }
  },
  mounted () {
    this.localOptions = this.options
  },
  computed: {
    inputValue: {
      get () {
        if (this.formStoreName && this.formNamespace) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    multiselectValue: {
      get () {
        if (this.collapseObject) {
          const options = (!this.groupValues)
            ? (this.localOptions ? this.localOptions : [])
            : this.localOptions.reduce((options, group) => { // flatten group
              options.push(...group[this.groupValues])
              return options
            }, [])
          if (options.length === 0) { // no options
            if (this.multiple) {
              const currentValue = (Array.isArray(this.inputValue)) ? this.inputValue : []
              return [...new Set(currentValue.map(value => {
                return { [this.trackBy]: value, [this.label]: value }
              }))]
            } else {
              const currentValue = (this.inputValue) ? this.inputValue : null
              return { [this.trackBy]: currentValue, [this.label]: currentValue }
            }
          } else { // is options
            if (this.multiple) {
              const currentValue = (Array.isArray(this.inputValue)) ? this.inputValue : []
              return [...new Set(currentValue.map(value => {
                return options.find(option => option[this.trackBy] === value) || { [this.trackBy]: value, [this.label]: value }
              }))]
            } else {
              const currentValue = (this.inputValue) ? this.inputValue : null
              return options.find(option => option[this.trackBy] === currentValue) || { [this.trackBy]: currentValue, [this.label]: currentValue }
            }
          }
        }
        return this.inputValue
      },
      set (newValue) {
        if (this.collapseObject) {
          newValue = (this.multiple)
            ? [...new Set(newValue.map(value => value[this.trackBy]))]
            : (newValue && newValue[this.trackBy])
        }
        this.inputValue = newValue
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    optionsList () {
      return (this.localOptions || []).map(option => {
        return option[this.trackBy]
      })
    },
    multiselectOptions () {
      if (this.internalSearchQuery) {
        const compoundSearch = (text, compoundQuery = null) => {
          if (!compoundQuery) return true
          let [ query, ...rest ] = compoundQuery.split(' ')
          // case-insensitive and locale-ized
          const textLocale = text.toLocaleLowerCase(this.$i18n.locale)
          const queryLocale = query.toLocaleLowerCase(this.$i18n.locale)
          if (rest.length > 0) {
            // && with recursion
            return (textLocale.includes(queryLocale) && compoundSearch(text, rest.join(' ')))
          }
          return textLocale.includes(queryLocale)
        }

        if (this.groupValues) {
          return this.localOptions.map(group => {
            const { [this.groupLabel]: groupLabel, [this.groupValues]: groupValues } = group
            if (compoundSearch(groupLabel, this.internalSearchQuery)) {
              return group
            }
            return {
              ...group,
              [this.groupValues]: groupValues.filter(option => {
                const { [this.label]: text } = option
                return compoundSearch(text, this.internalSearchQuery)
              })
            }
          }).filter(group => {
            const { [this.groupValues]: groupValues } = group
            return groupValues.length > 0
          })
        }
        else {
          return this.localOptions.filter(option => {
            const { [this.label]: text } = option
            return compoundSearch(text, this.internalSearchQuery)
          })
        }
      }
      else {
        return this.localOptions
      }
    },
    multiselectTagPlaceholder () {
      return this.tagPlaceholder || this.$i18n.t('Click to add value')
    }
  },
  methods: {
    focus () {
      const { $refs: { multiselect: { $el } = {} } = {} } = this
      $el.focus()
    },
    onFocus () {
      this.isFocus = true
      this.onSearchChange(this.inputValue)
    },
    blur () {
      const { $refs: { multiselect: { $el } = {} } = {} } = this
      $el.blur()
    },
    onBlur () {
      this.isFocus = false
      this.onSearchChange(this.inputValue)
    },
    onSearchChange (query) {
      if (this.internalSearch) {
        if (query !== this.inputValue) {
          this.internalSearchQuery = query
        }
        else {
          this.internalSearchQuery = null
        }
      }
      else if (this.optionsSearchFunction) {
        if (query && query.constructor === Array) { // not a user defined query
          query = ''
        }
        if (!this.$debouncer) {
          this.$debouncer = createDebouncer()
        }
        this.isLoading = true
        this.$debouncer({
          handler: () => {
            Promise.resolve(this.optionsSearchFunction(this, query, SEARCH_BY_TEXT)).then(options => {
              this.localOptions = options
            }).finally(() => {
              this.isLoading = false
            })
          },
          time: 300
        })
      }
    },
    removeTag (value) {
      this.inputValue = this.inputValue.filter(input => input !== value)
    },
    cacheTagsFromOptions (options) {
      if (this.groupValues) {
        let flattened = []
        for (let group of options) {
          flattened = [ ...flattened, ...( group[this.groupValues] || []) ]
        }
        options = flattened
      }
      (options || []).map(option => {
        const { [this.trackBy]: value, [this.label]: label } = option
        if (!(value in this.tagCache) || value !== label) {
          this.$set(this.tagCache, value, label)
        }
      })
    },
    addTag (newTag) {
      if (this.multiple) {
        this.$set(this, 'inputValue', [ ...this.inputValue, newTag ])
        this.focus()
      } else {
        this.$set(this, 'inputValue', newTag)
        this.blur()
      }
    }
  },
  watch: {
    options: {
      handler (a) {
        this.cacheTagsFromOptions(a)
        this.localOptions = a
      },
      immediate: true
    },
    inputValue: {
      handler (a) {
        this.internalSearchQuery = null
        if (a) {
          if (this.optionsSearchFunction) {
            (((this.multiple) ? a : [a]) || []).map(value => {
              if (!(value in this.tagCache)) {
                Promise.resolve(this.optionsSearchFunction(this, value, SEARCH_BY_ID)).then(options => {
                  this.cacheTagsFromOptions(options)
                })
              }
            })
          } else {
            this.cacheTagsFromOptions((((this.multiple) ? a : [a]) || []).map(value => {
              return { [this.label]: value, [this.trackBy]: value }
            }))
          }
        }
      },
      immediate: true
    }
  }
}
</script>

<style lang="scss">
/* See styles/_form-chosen.scss */

</style>
