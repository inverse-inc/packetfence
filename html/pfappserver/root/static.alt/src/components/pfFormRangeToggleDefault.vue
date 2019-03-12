<template>
  <b-form-group :horizontal="columnLabel" :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-range-toggle-default" :class="{ 'is-focus': focus, 'mb-0': !columnLabel }">
    <b-input type="text" ref="vacuum" readonly :value="null"
      style="overflow: hidden; width: 0px; height: 0px; margin: 0px; padding: 0px; border: 0px;"
      @focus.native="focus = true"
      @blur.native="focus = false"
      @keydown.native.space.prevent
      @keyup.native="keyUp"
    ><!-- Vaccum tabIndex --></b-input>
    <b-input-group :style="{ width: `${width}px` }">
      <label role="range" class="pf-form-range-toggle-default-label">
        <input-range
          :value="inputValue"
          @input="inputValue = $event"
          v-on="forwardListeners"
          min="0"
          max="2"
          step="1"
          :hints="hints"
          :color="color"
          :label="label"
          :tooltip="Object.keys(tooltips).length > 0"
          :tooltipFunction="tooltip"
          :width="width"
          class="mr-2"
          tabIndex="-1"
          @click="click"
        >
          <icon v-if="icon" :name="icon"></icon>
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
  name: 'pf-form-range-toggle-default',
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
        return { checked: true, unchecked: false, default: null }
      },
      validator (value) {
        return (value.checked && value.unchecked && 'default' in value)
      }
    },
    colors: {
      type: Object,
      default: () => { return {} },
      validator (value) {
        return (value.checked || value.unchecked || 'default' in value)
      }
    },
    icons: {
      type: Object,
      default: () => { return {} },
      validator (value) {
        return (value.checked || value.unchecked || 'default' in value)
      }
    },
    labels: {
      type: Object,
      default: () => { return {} },
      validator (value) {
        return (value.checked || value.unchecked || 'default' in value)
      }
    },
    tooltips: {
      type: Object,
      default: () => { return {} },
      validator (value) {
        return (value.left || value.middle || value.right)
      }
    },
    width: {
      type: Number,
      default: 60
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
            return 2
          case null:
            return 1
          case this.values.unchecked:
            return 0
        }
      },
      set (newValue) {
        switch (newValue) {
          case 0:
            this.$emit('input', this.values.unchecked)
            break
          case 1:
            this.$emit('input', null)
            break
          case 2:
            this.$emit('input', this.values.checked)
            break
        }
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    checked () {
      return parseInt(this.inputValue) === 2
    },
    unchecked () {
      return parseInt(this.inputValue) === 0
    },
    color () {
      if (this.colors === null) return null
      switch (this.inputValue) {
        case 2:
          return ('checked' in this.colors) ? this.colors.checked : null
        case 1:
          return ('default' in this.colors) ? this.colors.default : null
        case 0:
          return ('unchecked' in this.colors) ? this.colors.unchecked : null
      }
    },
    icon () {
      if (this.icons === null) return null
      switch (this.inputValue) {
        case 2:
          return ('checked' in this.icons) ? this.icons.checked : null
        case 1:
          return ('default' in this.icons) ? this.icons.default : null
        case 0:
          return ('unchecked' in this.icons) ? this.icons.unchecked : null
      }
    },
    label () {
      if (this.labels === null) return null
      switch (this.inputValue) {
        case 2:
          return ('checked' in this.labels) ? this.labels.checked : null
        case 1:
          return ('default' in this.labels) ? this.labels.default : null
        case 0:
          return ('unchecked' in this.labels) ? this.labels.unchecked : null
      }
    },
    hints () {
      let hints = []
      if ('default' in this.values && this.inputValue === 1) { /* default only */
        switch (true) {
          case (this.values.default === this.values.checked):
            hints.push([1, 2])
            break
          case (this.values.default === this.values.unchecked):
            hints.push([0, 1])
            break
        }
      }
      return hints
    }
  },
  methods: {
    tooltip () {
      if (this.tooltips === null) return null
      switch (this.inputValue) {
        case 2:
          return ('checked' in this.tooltips) ? this.tooltips.checked : null
        case 1:
          return ('default' in this.tooltips) ? this.tooltips.default : null
        case 0:
          return ('unchecked' in this.tooltips) ? this.tooltips.unchecked : null
      }
    },
    click (event) {
      this.$refs.vacuum.$el.focus() // focus vacuum
      this.inputValue = Math.round(event.layerX / event.target.clientWidth * 2) // use event vars to calc new value
    },
    keyUp (event) {
      switch (event.keyCode) {
        case 32: // space
          this.$set(this, 'inputValue', [1, 2, 0][this.inputValue]) // cycle forward
          return
        case 8: // backspace
          this.$set(this, 'inputValue', [2, 0, 1][this.inputValue]) // cycle backward
          return
        case 37: // arrow-left
        case 48: // 0
        case 96: // numpad 0
          this.$set(this, 'inputValue', 0) // set index 0
          return
        case 49: // 1
        case 97: // numpad 1
          this.$set(this, 'inputValue', 1) // set index 1
          return
        case 39: // arrow-right
        case 50: // 2
        case 98: // numpad 2
          this.$set(this, 'inputValue', 2) // set index 2
          return
      }
      if (this.values.checked.charAt(0).toLowerCase() !== this.values.unchecked.charAt(0).toLowerCase()) {
        // allow first character from value(s)
        switch (String.fromCharCode(event.keyCode).toLowerCase()) {
          case this.values.unchecked.charAt(0).toLowerCase():
            this.$set(this, 'inputValue', 0) // set index 0
            break
          case this.values.checked.charAt(0).toLowerCase():
            this.$set(this, 'inputValue', 2) // set index 2
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
  10%, 90% { background-color: rgba(0, 0, 0, 0.8); }
  20%, 80% { background-color: rgba(0, 0, 0, 0.6); }
  30%, 70% { background-color: rgba(0, 0, 0, 0.4); }
  40%, 60% { background-color: rgba(0, 0, 0, 0.2); }
  50% { background-color: rgba(0, 0, 0, 0); }
}

.pf-form-range-toggle-default {

  --handle-transition-delay: 0.3s; /* animate handle */

  &.is-focus .range {
    box-shadow: 0 0 0 1px $input-focus-border-color;

    .handle {
      /*background-color: $input-focus-border-color;*/
      background-color: rgba(0, 0, 0, 1); /* [range] background-color shows through */
      animation: animateCursor 2s infinite;
      box-sizing: border-box; /* inner border */
      border: 2px solid #fff;
    }
  }

  &.is-invalid .range {
    box-shadow: 0 0 0 1px $form-feedback-invalid-color;
  }

  .pf-form-range-toggle-default-label {
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

  .range {
    --handle-height: 16px;
    --range-height: 22px;
    &[index],
    &[index="0"],
    &[index="1"] {
      --range-background-color: #{$input-placeholder-color}; /* default unchecked background-color */
    }
    &[index="2"] {
      --range-background-color: var(--primary); /* default checked background-color */
    }
  }

  [size="sm"] .range { /* small / sm */
    --handle-height: 8px;
    --range-height: 11px;
    width: 20px;
  }

  [size="lg"] .range { /* large / lg */
    --handle-height: 32px;
    --range-height: 44px;
    width: 80px;
  }

}
</style>
