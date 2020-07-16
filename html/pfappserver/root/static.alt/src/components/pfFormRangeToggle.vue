<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-range-toggle" :class="{ 'is-focus': focus && !lazyLoading, 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input type="text" ref="vacuum" :value="null" :disabled="disabled" readonly
      style="overflow: hidden; width: 0px; height: 0px; margin: 0px; padding: 0px; border: 0px;"
      @focus.native="focus = true"
      @blur.native="focus = false"
      @keydown.native.space.prevent
      @keyup.native="keyUp"
    ><!-- Vaccum tabIndex --></b-input>
    <b-input-group :style="{ width: `${width}px` }">
      <label role="range" class="pf-form-range-toggle-label">
        <span v-if="leftLabel" class="mr-2" :class="{ 'text-secondary': lazyLoading }">{{ leftLabel }}</span>
        <input-range
          v-model="inputValue"
          v-on="forwardListeners"
          min="0"
          max="1"
          step="1"
          :color="color"
          :label="innerLabel"
          :listenInput="false"
          :tooltip="Object.keys(tooltips).length > 0"
          :tooltipFunction="tooltip"
          :width="width"
          :disabled="disabled || lazyLoading"
          class="d-inline-block"
          tabIndex="-1"
          @click="click"
        >
          <icon v-if="icon" :name="icon" :spin="lazyLoading"></icon>
        </input-range>
        <span v-if="rightLabel" class="ml-2" :class="{ 'text-secondary': lazyLoading }">{{ rightLabel }}</span>
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
  name: 'pf-form-range-toggle',
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
      default: () => {
        return { checked: true, unchecked: false }
      },
      validator (value) {
        return ('checked' in value && 'unchecked' in value)
      }
    },
    colors: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value)
    },
    icons: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value)
    },
    innerLabels: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value)
    },
    lazy: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value)
    },
    leftLabels: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value)
    },
    rightLabels: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value)
    },
    tooltips: {
      type: Object,
      default: () => ({}),
      validator: (value) => (Object.keys(value).length === 0 || 'checked' in value || 'unchecked' in value)
    },
    width: {
      type: [String, Number],
      default: 40
    }
  },
  data () {
    return {
      focus: false,
      lazyLoading: false
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
            return 1
          default:
            return 0
        }
      },
      set (newValue = null) {
        let previousValue // for lazyLoading
        switch (this.inputValue) {
          case 1:
            previousValue = this.values.checked
            break
          default:
            previousValue = this.values.unchecked
        }

        let value
        switch (parseInt(newValue)) {
          case 1:
            value = this.values.checked
            break
          default:
            value = this.values.unchecked
        }
        if (this.formStoreName) {
          this.formStoreValue = value // use FormStore
        } else {
          this.$emit('input', value) // use native (v-model)
        }

        // lazy handling
        if (Object.keys(this.lazy).length > 0) {
          const { lazy: { checked: lazyChecked, unchecked: lazyUnchecked } = {}, values: { checked, unchecked } = {} } = this
          switch (value) {
            case checked:
              this.lazyLoading = true
              Promise.resolve(lazyChecked(value)).then((lazyValue) => {
                value = lazyValue
              }).catch((newValue = previousValue) => {
                value = newValue
              }).finally(() => {
                this.lazyLoading = false
                if (this.formStoreName) {
                  this.formStoreValue = value // use FormStore
                } else {
                  this.$set(this, 'value', value)
                  this.$emit('input', this.value) // use native (v-model)
                }
              })
              break
            case unchecked:
              this.lazyLoading = true
              Promise.resolve(lazyUnchecked(value)).then((lazyValue) => {
                value = lazyValue
              }).catch((newValue = previousValue) => {
                value = newValue
              }).finally(() => {
                this.lazyLoading = false
                if (this.formStoreName) {
                  this.formStoreValue = value // use FormStore
                } else {
                  this.$set(this, 'value', value)
                  this.$emit('input', this.value) // use native (v-model)
                }
              })
              break
          }
        }
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    color () {
      if (Object.keys(this.colors).length === 0) return null
      return (this.inputValue === 1) ? this.colors.checked : this.colors.unchecked
    },
    icon () {
      if (this.lazyLoading) return 'circle-notch'
      if (Object.keys(this.icons).length === 0) return null
      return (this.inputValue === 1) ? this.icons.checked : this.icons.unchecked
    },
    innerLabel () {
      if (Object.keys(this.innerLabels).length === 0) return null
      if (this.lazyLoading) return null
      return (this.inputValue === 1) ? this.innerLabels.checked : this.innerLabels.unchecked
    },
    leftLabel () {
      if (Object.keys(this.leftLabels).length === 0) return null
      return (this.inputValue === 1) ? this.leftLabels.checked : this.leftLabels.unchecked
    },
    rightLabel () {
      if (Object.keys(this.rightLabels).length === 0) return null
      return (this.inputValue === 1) ? this.rightLabels.checked : this.rightLabels.unchecked
    }
  },
  methods: {
    tooltip () {
      return (this.checked) ? this.values.checked : this.values.unchecked
    },
    click (event) {
      this.$refs.vacuum.$el.focus() // focus vacuum
      this.toggle(event)
    },
    toggle () {
      this.inputValue = (this.inputValue === 1) ? 0 : 1
    },
    keyUp (event) {
      if (this.disabled || this.lazyLoading) return
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
      if (this.values.checked.toString().charAt(0).toLowerCase() !== this.values.unchecked.toString().charAt(0).toLowerCase()) {
        // allow first character from value(s)
        switch (String.fromCharCode(event.keyCode).toLowerCase()) {
          case this.values.unchecked.toString().charAt(0).toLowerCase():
            this.$set(this, 'inputValue', 0) // set index 0
            break
          case this.values.checked.toString().charAt(0).toLowerCase():
            this.$set(this, 'inputValue', 1) // set index 1
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

.pf-form-range-toggle {

  --handle-transition-delay: 0.3s; /* animate handle */

  &.is-focus .range {
    box-shadow: 0 0 0 1px $input-focus-border-color;

    .handle {
      box-sizing: border-box; /* inner border */
      border: 2px solid #fff;
      /*background-color: $input-focus-border-color;*/
      background-color: rgba(0, 0, 0, 1); /* [range] background-color shows through */
      animation: animateCursor 2s infinite;
    }
  }

  &.is-invalid .range {
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
  }

  .range {
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
