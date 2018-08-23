<template>
  <b-form-group :label-cols="labelCols" :label="$t(label)" :state="isValid()" :invalid-feedback="$t(invalidFeedback)" class="mb-0" horizontal>
    <b-input-group>
      <b-input-group-prepend v-if="prependText" is-text>
        {{ prependText }}
      </b-input-group-prepend>
      <b-form-input type="number" :placeholder="placeholder" v-model="inputValue" @input.native="validate()" :state="isValid()"></b-form-input>
      <b-form-text v-if="text" v-t="text"></b-form-text>
      <b-input-group-append>
        <b-button-group v-if="prefixes.length > 0" rel="prefixButtonGroup">
          <b-button v-for="(prefix, index) in prefixes" v-if="inRange(index)" :key="index" :variant="[prefix.selected ? 'primary' : 'light']" v-b-tooltip.hover.bottom.d300 :title="$t(prefix.name + units.name)" @click.stop="changeMultiplier($event, index)">{{ prefix.label + units.label }}</b-button>
        </b-button-group>
      </b-input-group-append>
    </b-input-group>
  </b-form-group>
</template>

<script>
import {createDebouncer} from 'promised-debounce'

export default {
  name: 'pf-form-input',
  model: {
    prop: 'realValue'
  },
  props: {
    realValue: {
      type: String
    },
    value: {
      default: null
    },
    label: {
      type: String
    },
    type: {
      type: String,
      default: 'text'
    },
    placeholder: { // Warning: This prop is not automatically translated.
      type: String,
      default: null
    },
    validation: {
      type: Object,
      default: null
    },
    text: {
      type: String,
      default: null
    },
    invalidFeedback: {
      type: String,
      default: null
    },
    highlightValid: {
      type: Boolean,
      default: false
    },
    debounce: {
      type: Number,
      default: 300
    },
    prependText: {
      type: String
    },
    units: {
      type: Object,
      default: {
        label: 'B',
        name: 'bytes'
      }
    },
    max: {
      type: Number,
      default: 4294967295 // Number.MAX_SAFE_INTEGER
    }
  },
  data () {
    return {
      inputValue: '',
      prefixes: [
        {
          label: '',
          name: '',
          multiplier: Math.pow(1024, 0),
          selected: true
        },
        {
          label: 'k',
          name: 'kilo',
          multiplier: Math.pow(1024, 1),
          selected: false
        },
        {
          label: 'M',
          name: 'mega',
          multiplier: Math.pow(1024, 2),
          selected: false
        },
        {
          label: 'G',
          name: 'giga',
          multiplier: Math.pow(1024, 3),
          selected: false
        },
        {
          label: 'T',
          name: 'tera',
          multiplier: Math.pow(1024, 4),
          selected: false
        },
        {
          label: 'P',
          name: 'peta',
          multiplier: Math.pow(1024, 5),
          selected: false
        },
        {
          label: 'X',
          name: 'exa',
          multiplier: Math.pow(1024, 6),
          selected: false
        },
        {
          label: 'Z',
          name: 'zetta',
          multiplier: Math.pow(1024, 7),
          selected: false
        },
        {
          label: 'Y',
          name: 'yotta',
          multiplier: Math.pow(1024, 8),
          selected: false
        }
      ]
    }
  },
  computed: {
    labelCols () {
      // do not reserve label column if no label
      return (this.label) ? 3 : 0
    }
  },
  methods: {
    isValid () {
      if (this.validation && this.validation.$dirty) {
        if (this.validation.$invalid) {
          return false
        } else if (this.highlightValid) {
          return true
        }
      }
      return null
    },
    validate () {
      const _this = this
      if (this.validation) {
        this.$debouncer({
          handler: () => {
            _this.validation.$touch()
          },
          time: this.debounce
        })
      }
    },
    changeMultiplier (event, newindex) {
      const curindex = this.prefixes.findIndex((prefix) => { return prefix.selected })
      if (curindex >= 0) {
        this.prefixes[curindex].selected = false
      }
      this.prefixes[newindex].selected = true
      this.realValue = this.inputValue * this.prefixes[newindex].multiplier
    },
    setInputValueFromRealValue () {
      // unselect all
      this.prefixes.filter((prefix) => { return prefix.selected }).forEach((prefix) => { prefix.selected = false })
      // sort prefixes descending using multiplier, to iterate in order
      const prefixes = JSON.parse(JSON.stringify(this.prefixes)).sort((a, b) => a.multiplier === b.multiplier ? 0 : a.multiplier < b.multiplier ? 1 : -1)
      // find LCD for value
      for (let i = 0; i < prefixes.length; i++) {
        let quotient = this.realValue / prefixes[i].multiplier
        if (quotient >= 1 && quotient === Math.round(quotient)) {
          const realIndex = this.prefixes.findIndex((p) => { return p.multiplier === prefixes[i].multiplier })
          this.prefixes[realIndex].selected = true
          this.inputValue = quotient.toString()
          break
        }
      }
      if (this.prefixes.findIndex((prefix) => { return prefix.selected }) === -1) {
        // no selection, select multiplier 1
        const index = this.prefixes.findIndex((prefix) => { return prefix.multiplier === 1 })
        if (index >= 0) {
          this.prefixes[index].selected = true
        }
      }
    },
    inRange (index) {
      return this.prefixes[index].multiplier <= this.max
    }
  },
  watch: {
    realValue (a, b) {
      if (a !== b) {
        // inputValue initialized later
        if (!this.initialized) {
          this.initialized = true
          this.setInputValueFromRealValue()
        }
        this.$emit('input', a)
      }
    },
    inputValue (a, b) {
      if (a !== b) {
        const selectedIndex = this.prefixes.findIndex((prefix) => { return prefix.selected })
        if (selectedIndex >= 0) {
          // scale up
          this.realValue = a * this.prefixes[selectedIndex].multiplier
        }
      }
    }
  },
  created () {
    this.$debouncer = createDebouncer()
  }
}
</script>

<style lang="scss" scoped>
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";

/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=prefixButtonGroup] button:hover {
  color: $input-btn-hover-text-color;
  background-color: $input-btn-hover-bg-color;
  border-color: $input-btn-hover-bg-color;
}
</style>
