<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)" :state="inputState"
    class="pf-form-prefix-multiplier" :class="{ 'mb-0': !columnLabel, 'is-focus': isFocus}">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input-group class="pf-form-prefix-multiplier-input-group">
      <b-input-group-prepend v-if="prependText">
        <div class="input-group-text">
          {{ prependText }}
        </div>
      </b-input-group-prepend>
      <b-form-input ref="input"
        v-model="humanValue"
        v-bind="$attrs"
        :state="inputState"
        type="number" pattern="[0-9]"
        @focus="isFocus = true"
        @blur="isFocus = false"
      ></b-form-input>
      <b-dropdown size="sm" v-if="prefixes.length > 0" variant="light">
        <template v-slot:button-content>
          <span class="mr-1">{{ currentPrefix.label  + units.label }}</span>
        </template>
        <template v-for="(prefix, index) in prefixesInRange">
          <b-dropdown-item-button :key="index" :active="currentPrefix.label === prefix.label" @click="changeMultiplier(index)">{{ $t(prefix.label + units.label) }}</b-dropdown-item-button>
        </template>
      </b-dropdown>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-prefix-multiplier',
  mixins: [
    pfMixinForm
  ],
  /*
  model: {
    prop: 'realValue'
  },
*/
  props: {
    realValue: {
      type: String
    },
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
    prependText: {
      type: String
    },
    units: {
      type: Object,
      default: () => ({
        label: 'B',
        name: 'bytes'
      })
    },
    max: {
      type: Number,
      default: 16 * Math.pow(1024, 6) // 16XB
    }
  },
  data () {
    return {
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
      ],
      isFocus: false
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
      set (newValue = null) {
        newValue = (newValue === 0) ? null : newValue
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    currentPrefix () {
      return this.prefixes.find(prefix => prefix.selected)
    },
    prefixesInRange () {
      return this.prefixes.filter(prefix => prefix.multiplier <= this.max)
    },
    humanValue: {
      get () {
        if (+this.inputValue !== 0) {
          // unselect all
          this.unSelectPrefix()
          // sort prefixes descending using multiplier, to iterate in order
          const prefixes = JSON.parse(JSON.stringify(this.prefixes)).sort((a, b) => a.multiplier === b.multiplier ? 0 : a.multiplier < b.multiplier ? 1 : -1)
          // find LCD for value
          for (let i = 0; i < prefixes.length; i++) {
            let quotient = this.inputValue / prefixes[i].multiplier
            if (Math.abs(quotient) >= 1 && quotient === Math.round(quotient)) {
              const index = this.prefixes.findIndex((p) => { return p.multiplier === prefixes[i].multiplier })
              // eslint-disable-next-line vue/no-side-effects-in-computed-properties
              this.prefixes[index].selected = true
              return quotient.toString()
            }
          }
          if (this.prefixes.findIndex((prefix) => { return prefix.selected }) === -1) {
            // no selection, select multiplier 1
            const index = this.prefixes.findIndex((prefix) => { return prefix.multiplier === 1 })
            if (index >= 0) {
              // eslint-disable-next-line vue/no-side-effects-in-computed-properties
              this.prefixes[index].selected = true
            }
          }
        }
        return this.inputValue
      },
      set (newValue) {
        if (+newValue === 0) {
          this.inputValue = null
        } else {
          let multiplier = 1
          const selectedIndex = this.prefixes.findIndex((prefix) => { return prefix.selected })
          if (selectedIndex >= 0) {
            // scale up
            multiplier = this.prefixes[selectedIndex].multiplier
          }
          this.inputValue = +newValue * multiplier
        }
      }
    }
  },
  methods: {
    focus () {
      this.$refs.input.focus()
    },
    changeMultiplier (newIndex) {
      if (+this.inputValue !== 0) {
        const curIndex = this.prefixes.findIndex((prefix) => { return prefix.selected })
        const factor = this.prefixes[newIndex].multiplier / this.prefixes[curIndex].multiplier
        this.inputValue *= factor
      } else {
        this.prefixes.find(prefix => prefix.selected).selected = false
        this.prefixes[newIndex].selected = true
      }
    },
    unSelectPrefix () {
      this.prefixes.filter((prefix) => { return prefix.selected }).forEach((prefix) => { prefix.selected = false })
    }
  }
}
</script>

<style lang="scss" scoped>
/**
 * Adjust is-invalid and is-focus borders
 */
.pf-form-prefix-multiplier {
  .pf-form-prefix-multiplier-input-group {
    padding: 1px;
    border: 1px solid $input-focus-bg;
    background-color: $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;

    * {
      border: 0px;
    }
    &:not(:first-child):not(:last-child):not(:only-child),
    &.btn-group:first-child {
      border-radius: 0;
    }
    &:first-child {
      border-top-left-radius: $border-radius;
      border-bottom-left-radius: $border-radius;
    }
    &:last-child {
      border-top-right-radius: $border-radius;
      border-bottom-right-radius: $border-radius;
    }
  }
  &.is-focus .pf-form-prefix-multiplier-input-group {
    border: 1px solid $input-focus-border-color;
    box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
  }
  &.is-invalid .pf-form-prefix-multiplier-input-group {
    border: 1px solid $form-feedback-invalid-color;
    box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
  }
}
</style>
