<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-range-toggle" :class="{ 'is-focus': focus, 'mb-0': !columnLabel }">
    <b-input type="text" ref="vacuum" readonly :value="null"
      style="position: absolute; width: 1px; height: 1px; left: -9999px; padding: 0px; border: 0px;"
      @focus.native="focus = true"
      @blur.native="focus = false"
      @keydown.native.space.prevent
      @keyup.native="keyUp"
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
          :tooltip="tooltip"
          :tooltipFunction="tooltipFunction"
          :width="width"
          class="mr-2"
          tabIndex="-1"
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
      default: () => { return {} },
      validator (value) {
        return (value.checked && value.unchecked)
      }
    },
    icons: {
      type: Object,
      default: () => { return {} },
      validator (value) {
        return (value.checked && value.unchecked)
      }
    },
    labels: {
      type: Object,
      default: () => { return {} },
      validator (value) {
        return (value.checked && value.unchecked)
      }
    },
    width: {
      type: Number,
      default: 40
    },
    tooltip: {
      type: Boolean,
      default: true
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
        switch (this.value) {
          case this.values.checked:
            return 1
          default:
            return 0
        }
      },
      set (newValue) {
        switch (newValue) {
          case 1:
            this.$emit('input', this.values.checked)
            break
          default:
            this.$emit('input', this.values.unchecked)
        }
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    color () {
      if (this.colors === null) return null
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
    tooltipFunction () {
      return (this.checked) ? this.values.checked : this.values.unchecked
    },
    click (event) {
      this.$refs.vacuum.$el.focus() // focus vacuum
      this.toggle(event)
    },
    toggle (event) {
      this.inputValue = (this.inputValue === 1) ? 0 : 1
    },
    keyUp (event) {
      switch (event.keyCode) {
        case 8: // backspace
        case 32: // space
          this.$set(this, 'inputValue', [1, 0][this.inputValue]) // cycle
          return
        case 37: // arrow-left
        case 48: // 0
        case 96: // numpad 0
          this.$set(this, 'inputValue', 0) // set index 0
          return
        case 39: // arrow-right
        case 49: // 1
        case 97: // numpad 1
          this.$set(this, 'inputValue', 1) // set index 1
          return
      }
      if (this.values.checked.charAt(0).toLowerCase() !== this.values.unchecked.charAt(0).toLowerCase()) {
        // allow first character from value(s)
        switch (String.fromCharCode(event.keyCode).toLowerCase()) {
          case this.values.unchecked.charAt(0).toLowerCase():
            this.$set(this, 'inputValue', 0) // set index 0
            break
          case this.values.checked.charAt(0).toLowerCase():
            this.$set(this, 'inputValue', 1) // set index 1
            break
        }
      }
    }
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";
@import "../../node_modules/bootstrap/scss/root";

@keyframes animateCursor {
  0%, 100% { background-color: rgba(0, 0, 0, 1); }
  10% { background-color: rgba(0, 0, 0, 0.8); }
  20% { background-color: rgba(0, 0, 0, 0.6); }
  30% { background-color: rgba(0, 0, 0, 0.4); }
  40% { background-color: rgba(0, 0, 0, 0.2); }
  50% { background-color: rgba(0, 0, 0, 0); }
  60% { background-color: rgba(0, 0, 0, 0.2); }
  70% { background-color: rgba(0, 0, 0, 0.4); }
  80% { background-color: rgba(0, 0, 0, 0.6); }
  90% { background-color: rgba(0, 0, 0, 0.8); }

}

.pf-form-range-toggle {

  --handle-transition-delay: 0.3s; /* animate handle */

  &.is-focus [range] {
    box-shadow: 0 0 0 1px $input-focus-border-color;

    [handle] {
      /*background-color: $input-focus-border-color;*/
      background-color: rgba(0, 0, 0, 1); /* [range] background-color shows through */
      animation: animateCursor 2s infinite;
      box-sizing: border-box; /* inner border */
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
    --handle-height: 16px;
    --range-height: 22px;
    &[index],
    &[index="0"] {
      --range-background-color: #adb5bd; /* default unchecked background-color */
    }
    &[index="1"] {
      --range-background-color: var(--primary); /* default checked background-color */
    }
  }

  [size="sm"] [range] { /* small / sm */
    --handle-height: 8px;
    --range-height: 11px;
    width: 20px;
  }

  [size="lg"] [range] { /* large / lg */
    --handle-height: 32px;
    --range-height: 44px;
    width: 80px;
  }

}
</style>
