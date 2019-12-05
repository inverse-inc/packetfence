<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)" :state="inputState"
    class="pf-form-prefix-multiplier" :class="{ 'mb-0': !columnLabel, 'is-focus': focus}">
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
        :type="type"
        @focus.native="focus = true"
        @blur.native="focus = false"
      ></b-form-input>
      <b-input-group-append>
        <b-button-group v-if="prefixes.length > 0" rel="prefixButtonGroup">
          <b-button v-for="(prefix, index) in prefixes" v-if="inRange(index)" :key="index" :variant="[prefix.selected ? 'primary' : 'light']" v-b-tooltip.hover.bottom.d300 :title="$t(prefix.name + units.name)" @click.stop="changeMultiplier($event, index)" tabindex="-1">{{ $t(prefix.label + units.label) }}</b-button>
        </b-button-group>
      </b-input-group-append>
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
    type: {
      type: String,
      default: 'number'
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
      default: 4294967295 // Number.MAX_SAFE_INTEGER
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
      focus: false
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
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    humanValue: {
      get () {
        if (this.inputValue > 0) {
          // unselect all
          this.unSelectPrefix()
          // sort prefixes descending using multiplier, to iterate in order
          const prefixes = JSON.parse(JSON.stringify(this.prefixes)).sort((a, b) => a.multiplier === b.multiplier ? 0 : a.multiplier < b.multiplier ? 1 : -1)
          // find LCD for value
          for (let i = 0; i < prefixes.length; i++) {
            let quotient = this.inputValue / prefixes[i].multiplier
            if (quotient >= 1 && quotient === Math.round(quotient)) {
              const index = this.prefixes.findIndex((p) => { return p.multiplier === prefixes[i].multiplier })
              this.prefixes[index].selected = true
              return quotient.toString()
            }
          }
          if (this.prefixes.findIndex((prefix) => { return prefix.selected }) === -1) {
            // no selection, select multiplier 1
            const index = this.prefixes.findIndex((prefix) => { return prefix.multiplier === 1 })
            if (index >= 0) {
              this.prefixes[index].selected = true
            }
          }
        }
        return this.inputValue
      },
      set (newValue) {
        const selectedIndex = this.prefixes.findIndex((prefix) => { return prefix.selected })
        let multiplier = 1
        if (selectedIndex >= 0) {
          // scale up
          multiplier = this.prefixes[selectedIndex].multiplier
        }
        this.inputValue = newValue * multiplier
      }
    }
  },
  methods: {
    changeMultiplier (event, newIndex) {
      const curIndex = this.prefixes.findIndex((prefix) => { return prefix.selected })
      const factor = this.prefixes[newIndex].multiplier / this.prefixes[curIndex].multiplier
      this.inputValue *= factor
    },
    inRange (index) {
      return this.prefixes[index].multiplier <= this.max
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

/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=prefixButtonGroup] button:hover {
  background-color: $input-btn-hover-bg-color;
  color: $input-btn-hover-text-color;
  border-color: $input-btn-hover-bg-color;
}
</style>
