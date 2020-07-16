<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-range-toggle-default" :class="{ 'is-focus': focus, 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input type="text" ref="vacuum" readonly :value="null" :disabled="disabled"
      style="overflow: hidden; width: 0px; height: 0px; margin: 0px; padding: 0px; border: 0px;"
      @focus.native="focus = true"
      @blur.native="focus = false"
      @keydown.native.space.prevent
      @keyup.native="keyUp"
    ><!-- Vaccum tabIndex --></b-input>
    <b-input-group :style="{ width: `${width}px` }">
      <label role="range" class="pf-form-range-toggle-default-label">
        <span class="mr-2" v-if="leftLabel">{{ leftLabel }}</span>
        <input-range
          :value="inputValue"
          @input="inputValue = $event"
          v-on="forwardListeners"
          min="0"
          max="2"
          step="1"
          :hints="hints"
          :color="color"
          :label="innerLabel"
          :tooltip="Object.keys(tooltips).length > 0"
          :tooltipFunction="tooltip"
          :width="width"
          :disabled="disabled"
          class="d-inline-block"
          tabIndex="-1"
          @click="click"
        >
          <icon v-if="icon" :name="icon"></icon>
        </input-range>
        <span class="ml-2" v-if="rightLabel">{{ rightLabel }}</span>
        <slot class="ml-2"/>
      </label>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import InputRange from '@/components/InputRange'
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-range-toggle-default',
  mixins: [
    pfMixinForm
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
      type: [String, Number],
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
      default: () => ({ checked: true, unchecked: false, default: null }),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value || 'default' in value)
    },
    colors: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value || 'default' in value)
    },
    icons: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value || 'default' in value)
    },
    innerLabels: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value || 'default' in value)
    },
    leftLabels: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value || 'default' in value)
    },
    rightLabels: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value || 'default' in value)
    },
    tooltips: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value || 'default' in value)
    },
    width: {
      type: [String, Number],
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
        let value
        if (this.formStoreName) {
          value = this.formStoreValue // use FormStore
        } else {
          value = this.value // use native (v-model)
        }
        switch (value) {
          case this.values.checked:
            return 2
          case null:
            return 1
          case this.values.unchecked:
            return 0
        }
        return 1
      },
      set (newValue = null) {
        let value
        switch (~~newValue) {
          case 0:
            value = this.values.unchecked
            break
          case 1:
            value = null
            break
          case 2:
            value = this.values.checked
            break
        }
        if (this.formStoreName) {
          this.formStoreValue = value // use FormStore
        } else {
          this.$emit('input', value) // use native (v-model)
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
      if (this.colors) {
        switch (this.inputValue) {
          case 2:
            return ('checked' in this.colors) ? this.colors.checked : null
          case 1:
            return ('default' in this.colors) ? this.colors.default : null
          case 0:
            return ('unchecked' in this.colors) ? this.colors.unchecked : null
        }
      }
      return null
    },
    icon () {
      if (this.icons) {
        switch (this.inputValue) {
          case 2:
            return ('checked' in this.icons) ? this.icons.checked : null
          case 1:
            return ('default' in this.icons) ? this.icons.default : null
          case 0:
            return ('unchecked' in this.icons) ? this.icons.unchecked : null
        }
      }
      return null
    },
    innerLabel () {
      if (this.innerLabels) {
        switch (this.inputValue) {
          case 2:
            return ('checked' in this.innerLabels) ? this.innerLabels.checked : null
          case 1:
            return ('default' in this.innerLabels) ? this.innerLabels.default : null
          case 0:
            return ('unchecked' in this.innerLabels) ? this.innerLabels.unchecked : null
        }
      }
      return null
    },
    leftLabel () {
      if (this.leftLabels) {
        switch (this.inputValue) {
          case 2:
            return ('checked' in this.leftLabels) ? this.leftLabels.checked : null
          case 1:
            return ('default' in this.leftLabels) ? this.leftLabels.default : null
          case 0:
            return ('unchecked' in this.leftLabels) ? this.leftLabels.unchecked : null
        }
      }
      return null
    },
    rightLabel () {
      if (this.rightLabels) {
        switch (this.inputValue) {
          case 2:
            return ('checked' in this.rightLabels) ? this.rightLabels.checked : null
          case 1:
            return ('default' in this.rightLabels) ? this.rightLabels.default : null
          case 0:
            return ('unchecked' in this.rightLabels) ? this.rightLabels.unchecked : null
        }
      }
      return null
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
      if (this.tooltips) {
        switch (~~this.inputValue) {
          case 2:
            return ('checked' in this.tooltips) ? this.tooltips.checked : null
          case 1:
            return ('default' in this.tooltips) ? this.tooltips.default : null
          case 0:
            return ('unchecked' in this.tooltips) ? this.tooltips.unchecked : null
        }
      }
      return null
    },
    click (event) {
      this.$refs.vacuum.$el.focus() // focus vacuum
      this.inputValue = Math.round(event.layerX / event.target.clientWidth * 2) // use event vars to calc new value
    },
    keyUp (event) {
      if (this.disabled) return
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
      if (this.values.checked.toString().charAt(0).toLowerCase() !== this.values.unchecked.toString().charAt(0).toLowerCase()) {
        // allow first character from value(s)
        switch (String.fromCharCode(event.keyCode).toLowerCase()) {
          case this.values.unchecked.toString().charAt(0).toLowerCase():
            this.$set(this, 'inputValue', 0) // set index 0
            break
          case this.values.checked.toString().charAt(0).toLowerCase():
            this.$set(this, 'inputValue', 2) // set index 2
            break
        }
      }
    }
  }
}
</script>

<style lang="scss">
@keyframes animateCursor {
  0%, 100% { background-color: rgba(255, 255, 255, 1); }
  5%, 95% { background-color: rgba(255, 255, 255, 0.9); }
  10%, 90% { background-color: rgba(255, 255, 255, 0.8); }
  15%, 85% { background-color: rgba(255, 255, 255, 0.7); }
  20%, 80% { background-color: rgba(255, 255, 255, 0.6); }
  25%, 75% { background-color: rgba(255, 255, 255, 0.5); }
  30%, 70% { background-color: rgba(255, 255, 255, 0.4); }
  35%, 65% { background-color: rgba(255, 255, 255, 0.3); }
  40%, 60% { background-color: rgba(255, 255, 255, 0.2); }
  45%, 55% { background-color: rgba(255, 255, 255, 0.1); }
  50% { background-color: rgba(255, 255, 255, 0); }
}

.pf-form-range-toggle-default {

  --handle-transition-delay: 0.3s; /* animate handle */

  &.is-focus .range {
    box-shadow: 0 0 0 1px $input-focus-border-color;

    .handle {
      /*background-color: $input-focus-border-color;*/
      box-sizing: border-box; /* inner border */
      border: 2px solid #fff;
      background-color: rgba(0, 0, 0, 1); /* [range] background-color shows through */
      animation: animateCursor 2s infinite;
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
    font-size: $font-size-sm;
    font-weight: 600;
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
