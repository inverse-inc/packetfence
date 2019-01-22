<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-range-toggle" :class="{ 'is-focus': focus, 'mb-0': !columnLabel }">
    <b-input type="text" ref="vacuum" readonly :value="null"
      style="position: absolute; width: 1px; height: 1px; left: -9999px; padding: 0px; border: 0px;"
      @focus.native="focus = true"
      @blur.native="focus = false"
      @keydown.native.space.prevent
      @keyup.native.space="toggle"
    ><!-- Vaccum tabIndex --></b-input>
    <b-input-group :style="{ width: `${width}px` }">
      <label role="range" class="pf-form-range-toggle-label">
        <input-range
          v-model="inputValue"
          v-on="forwardListeners"
          min="0"
          max="1"
          step="1"
          :color="color"
          :label="label"
          :listenInput="false"
          :tooltipFunction="tooltip"
          :width="width"
          class="mr-2"
          tabIndex="-1"
          tooltip
          @click="click"
        >
          <icon v-if="icons" :name="icon"></icon>
        </input-range>
        <slot/>
      </label>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
import InputRange from '@/components/InputRange'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-range-toggle',
  mixins: [
    pfMixinValidation
  ],
  components: {
    InputRange
  },
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
    disabled: {
      type: Boolean,
      default: false
    },
    values: {
      type: Object,
      default: () => {
        return { checked: true, unchecked: false }
      },
      validator (value) {
        return (value.checked && value.unchecked)
      }
    },
    colors: {
      type: Object,
      default: null,
      validator (value) {
        return (value.checked || value.unchecked)
      }
    },
    icons: {
      type: Object,
      default: false,
      validator (value) {
        return (value.checked && value.unchecked)
      }
    },
    labels: {
      type: Object,
      default: false,
      validator (value) {
        return (value.checked && value.unchecked)
      }
    },
    width: {
      type: Number,
      default: 40
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
        switch (this.values.constructor) {
          case Boolean:
            return (this.value === this.values) ? 1 : 0
          case Object:
            return (this.value === this.values.checked) ? 1 : 0
        }
        return 0
      },
      set (newValue) {
        switch (this.values.constructor) {
          case Boolean:
            this.$emit('input', (newValue === 1) ? this.value : !this.value)
            break
          case Object:
            this.$emit('input', (newValue === 1) ? this.values.checked : this.values.unchecked)
            break
        }
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    checked () {
      return parseInt(this.inputValue) === 1
    },
    unchecked () {
      return !this.checked
    },
    color () {
      if(this.colors === null) return null
      return (this.inputValue === 1) ? this.colors.checked : this.colors.unchecked
    },
    icon () {
      if (this.icons === null) return null
      return (this.inputValue === 1) ? this.icons.checked : this.icons.unchecked
    },
    label () {
      if (this.labels === null) return null
      return (this.inputValue === 1) ? this.labels.checked : this.labels.unchecked
    }
  },
  methods: {
    tooltip (value) {
      return (this.checked) ? this.values.checked : this.values.unchecked
    },
    click (event) {
      this.$refs.vacuum.$el.focus() // focus vacuum
      this.inputValue = (this.checked) ? 0 : 1
    },
    toggle (event) {
      this.inputValue = (this.inputValue === 1) ? 0 : 1
    }
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";
@import "../../node_modules/bootstrap/scss/root";

.pf-form-range-toggle {

  &.is-focus [range] {
    box-shadow: 0 0 0 1px $input-focus-border-color;

    [handle] {
      background-color: $input-focus-border-color;
      box-sizing: border-box;
      border: 2px solid #fff;
    }
  }

  &.is-invalid [range] {
    box-shadow: 0 0 0 1px $form-feedback-invalid-color;
  }

  .pf-form-range-toggle-label {
    display: inline-flex;
    align-items: center;
    /* overflow: hidden; */
    padding-top: calc(#{$input-padding-y} + #{$input-border-width});
    vertical-align: middle;
    margin: 0;
    user-select: none;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
  }

  [range] {
    --handle-transition-delay: 0.3s; /* animate handle */
    --handle-height: 16px;
    --range-height: 22px;

    &[index],
    &[index="0"] {
      --range-background-color: #adb5bd;
      path { /* SVG icon */
        color: #adb5bd;
        transition: color var(--range-transition-delay) ease-out;
      }
    }
    &[index="1"] {
      --range-background-color: var(--primary);
      path { /* SVG icon */
        color: var(--primary);
        transition: color var(--range-transition-delay) ease-out;
      }
    }
  }

  [size="sm"] [range] { /* small / sm */
    --range-height: 11px;
    --handle-height: 8px;
    width: 20px;
  }

  [size="lg"] [range] { /* large / lg */
    --range-height: 44px;
    --handle-height: 32px;
    width: 80px;
  }

}
</style>
