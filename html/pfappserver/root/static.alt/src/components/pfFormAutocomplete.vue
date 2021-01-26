<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-autocomplete" :class="{ 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input-group>
      <b-form-input ref="input"
        v-model="inputValue"
        v-bind="$attrs"
        :state="inputState"
        :class="{ 'form-control-with-suggestions': suggestions.length && visible }"
        @blur="hideSuggestions"
        @focus="showSuggestions"
        @keyup.up.stop="highlightPrevious"
        @keyup.down.stop="highlightNext"
        @keyup.enter.stop="selectHighlighted"
        @keyup.delete="hideSuggestions"
      ></b-form-input>
      <ul class="pf-form-autocomplete-suggestions dropdown-menu" :class="{ show: suggestions.length && visible }"
        @mouseout="resetHightlight" @mousedown="selectHighlighted">
        <li class="pf-form-autocomplete-suggestion form-control" v-for="(match, index) in suggestions" :key="match"
          :class="{ 'pf-form-autocomplete-suggestion-highlighted': isHighlighted(index) }"
          @mouseover="highlightIndex(index)">
          <span v-html="highlight(match)"></span>
        </li>
      </ul>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import { createDebouncer } from 'promised-debounce'
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-autocomplete',
  mixins: [
    pfMixinForm
  ],
  inheritAttrs: false,
  props: {
    value: {
      default: null
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
    suggestions: {
      type: Array
    },
    minLength: {
      type: Number,
      default: 3
    },
    debounce: {
      type: Number,
      default: 300
    }
  },
  data () {
    return {
      visible: false,
      invalid: false,
      highlightedIndex: -1
    }
  },
  computed: {
    inputValue: {
      get () {
        if (this.formStoreName) {
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
        if (!this.$debouncer) {
          this.$debouncer = createDebouncer()
        }
        this.$debouncer({
          handler: () => {
            if (newValue.length >= this.minLength && newValue !== this.value) {
              this.visible = true
              this.resetHightlight()
              this.$emit('search', newValue)
            }
          },
          time: this.debounce
        })
      }
    }
  },
  methods: {
    focus () {
      this.$refs.input.focus()
    },
    hideSuggestions () {
      this.visible = false
    },
    showSuggestions () {
      if (!this.invalid) {
        this.visible = true
      }
    },
    resetSuggestions () {
      this.invalid = true
    },
    highlight (match) {
      let pos = match.toLowerCase().indexOf(this.inputValue.toLowerCase())
      if (pos >= 0) {
        let escapedValue = this.inputValue.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
        let re = new RegExp(`(${escapedValue})`, 'gi')
        return match.replace(re, '<b>$1</b>')
      } else {
        return match
      }
    },
    highlightPrevious () {
      if (this.highlightedIndex > 0) {
        this.highlightedIndex--
      }
    },
    highlightNext () {
      if (this.highlightedIndex < this.suggestions.length - 1) {
        this.highlightedIndex++
      }
    },
    highlightIndex (index) {
      this.highlightedIndex = index
    },
    isHighlighted (index) {
      return this.suggestions.length === 1 || index === this.highlightedIndex
    },
    selectHighlighted () {
      if (this.suggestions.length === 1) {
        this.highlightedIndex = 0
      }
      if (this.highlightedIndex >= 0) {
        if (this.formStoreName) {
          this.formStoreValue = this.suggestions[this.highlightedIndex] // use FormStore
        } else {
          this.$emit('input', this.suggestions[this.highlightedIndex]) // use native (v-model)
        }
        this.hideSuggestions()
        this.resetSuggestions()
        this.resetHightlight()
      }
    },
    resetHightlight () {
      this.highlightedIndex = -1
    }
  }
}
</script>

<style lang="scss">
.pf-form-autocomplete {
    position: relative;
    // Input field
    .form-control-with-suggestions {
        border-bottom-left-radius: 0%;
        border-bottom-right-radius: 0%;
        &:focus {
            border-bottom-color: $input-border-color;
        }
    }
    // Matching values
    .pf-form-autocomplete-suggestions.dropdown-menu {
        width: 100%;
        padding: 0;
        border-top: none;
        border-top-left-radius: 0%;
        border-top-right-radius: 0%;
        float: none;
        margin: 0;
        // From @mixin form-control-focus()
        box-shadow: $input-box-shadow, $input-focus-box-shadow;
        border-color: $input-focus-border-color;
        border-top-color: $input-border-color;
        .pf-form-autocomplete-suggestion.form-control {
            border: 0;
            border-top-left-radius: 0%;
            border-top-right-radius: 0%;
            cursor: pointer;
            &:not(:last-child) {
              border-bottom-left-radius: 0%;
              border-bottom-right-radius: 0%;
            }
            &.pf-form-autocomplete-suggestion-highlighted {
                background-color: $component-active-bg;
                color: $component-active-color;
            }
        }
    }
}
</style>
