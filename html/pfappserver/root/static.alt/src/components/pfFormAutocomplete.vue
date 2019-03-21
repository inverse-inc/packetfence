<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()" :class="{ 'mb-0': !columnLabel }">
    <div class="pf-autocomplete">
      <b-form-input
        v-model="inputValue"
        v-bind="$attrs"
        :class="{ 'form-control-with-suggestions': suggestions.length && visible }"
        :state="isValid()"
        @blur.native="hideSuggestions"
        @focus.native="showSuggestions"
        @keyup.native.up.stop="highlightPrevious"
        @keyup.native.down.stop="highlightNext"
        @keyup.native.enter.stop="selectHighlighted"
        @keyup.native.delete="hideSuggestions"
        @input.native="validate()"
        @keyup.native.stop="onChange($event)"
        @change.native="onChange($event)"
      ></b-form-input>
      <ul class="pf-autocomplete-suggestions dropdown-menu" :class="{ show: suggestions.length && visible }"
        @mouseout="resetHightlight" @mousedown="selectHighlighted">
        <li class="pf-autocomplete-suggestion form-control" v-for="(match, index) in suggestions" :key="match"
          :class="{ 'pf-autocomplete-suggestion-highlighted': isHighlighted(index) }"
          @mouseover="highlightIndex(index)">
          <span v-html="highlight(match)"></span>
        </li>
      </ul>
    </div>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import { createDebouncer } from 'promised-debounce'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-autocomplete',
  mixins: [
    pfMixinValidation
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
      default: 2
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
        return this.value
      },
      set (newValue) {
        const _this = this
        this.$debouncer({
          handler: () => {
            if (newValue.length > _this.minLength && newValue !== _this.value) {
              _this.visible = true
              this.resetHightlight()
              _this.$emit('input', newValue)
              _this.$emit('search', newValue)
            }
          },
          time: this.debounce
        })
      }
    }
  },
  methods: {
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
      let pos = match.toLowerCase().indexOf(this.value.toLowerCase())
      if (pos >= 0) {
        let escapedValue = this.value.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
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
        this.$emit('input', this.suggestions[this.highlightedIndex])
        this.hideSuggestions()
        this.resetSuggestions()
        this.resetHightlight()
      }
    },
    resetHightlight () {
      this.highlightedIndex = -1
    }
  },
  created () {
    this.$debouncer = createDebouncer()
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";

.pf-autocomplete {
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
    .pf-autocomplete-suggestions.dropdown-menu {
        border-top: none;
        border-top-left-radius: 0%;
        border-top-right-radius: 0%;
        float: none;
        margin: 0;
        padding: 0;
        width: 100%;
        // From @mixin form-control-focus()
        box-shadow: $input-box-shadow, $input-focus-box-shadow;
        border-color: $input-focus-border-color;
        border-top-color: $input-border-color;
        .pf-autocomplete-suggestion.form-control {
            border: 0;
            border-top-left-radius: 0%;
            border-top-right-radius: 0%;
            cursor: pointer;
            &:not(:last-child) {
              border-bottom-left-radius: 0%;
              border-bottom-right-radius: 0%;
            }
            &.pf-autocomplete-suggestion-highlighted {
                background-color: $component-active-bg;
                color: $component-active-color;
            }
        }
    }
}
</style>
