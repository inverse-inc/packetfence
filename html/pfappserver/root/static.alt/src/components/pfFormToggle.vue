<!--
  https://github.com/euvl/vue-js-toggle-button

  Other sources of inspiration:

  https://lusaxweb.github.io/vuesax/#/docs/switch
  https://vmware.github.io/clarity/documentation/v0.11/toggle-switches
-->
<template>
  <component class="v-switch-wrapper" :class="{ 'is-focus': focus }" :is="wrapper" horizontal :label-cols="(columnLabel) ? 3 : 0" :label="$t(columnLabel)">
    <b-input type="text" name="vaccum" readonly :value="null" style="position: absolute; width: 1px; height: 1px; left: -9999px;"
      @focus.native="focus = true" @blur.native="focus = false" @keyup.native.space="toggle"><!-- Vaccum tabIndex --></b-input>
    <label role="checkbox"
          :class="className"
          :aria-checked="ariaChecked">
      <input type="checkbox"
            class="v-switch-input"
            @change.stop="toggle">
      <div class="v-switch-core mr-2"
            :style="coreStyle">
        <div class="v-switch-button"
            :style="buttonStyle"/>
      </div>
      <template v-if="labels">
        <span class="v-switch-label v-left"
              :style="labelStyle"
              v-if="toggled"
              v-html="labelChecked"/>
        <span class="v-switch-label v-right"
              :style="labelStyle"
              v-else
              v-html="labelUnchecked"/>
      </template>
      <slot/>
    </label>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </component>
</template>

<script>
const constants = {
  colorChecked: null, // default is $blue
  colorUnchecked: null, // default is $gray-500
  labelChecked: 'on',
  labelUnchecked: 'off',
  width: 40,
  height: 22,
  margin: 3
}
const contains = (object, title) => {
  return typeof object === 'object' && object.hasOwnProperty(title)
}
const px = v => v + 'px'
export default {
  name: 'pf-form-toggle',
  props: {
    value: {
      default: null
    },
    values: {
      type: [Boolean, Object],
      default: () => ({
        checked: true,
        unchecked: false
      }),
      validator (value) {
        return typeof value === 'object'
          ? (value.checked || value.unchecked)
          : typeof value === 'boolean'
      }
    },
    disabled: {
      type: Boolean,
      default: false
    },
    color: {
      type: [String, Object],
      default: () => ({
        checked: constants.colorChecked,
        unchecked: constants.colorUnchecked
      }),
      validator (value) {
        return typeof value === 'object'
          ? (value.checked || value.unchecked)
          : typeof value === 'string'
      }
    },
    cssColors: {
      type: Boolean,
      default: false
    },
    columnLabel: {
      type: String,
      default: null
    },
    labels: {
      type: [Boolean, Object],
      default: false,
      validator (value) {
        return typeof value === 'object'
          ? (value.checked || value.unchecked)
          : typeof value === 'boolean'
      }
    },
    text: {
      type: String,
      default: null
    },
    height: {
      type: Number,
      default: constants.height
    },
    width: {
      type: Number,
      default: constants.width
    }
  },
  computed: {
    wrapper () {
      return this.columnLabel ? 'b-form-group' : 'div'
    },
    className () {
      let { toggled, disabled } = this
      return ['vue-js-switch', { toggled, disabled }]
    },
    ariaChecked () {
      return this.toggled.toString()
    },
    coreStyle () {
      return {
        width: px(this.width),
        height: px(this.height),
        backgroundColor: this.cssColors ? null : this.colorCurrent,
        borderRadius: px(Math.round(this.height / 2))
      }
    },
    buttonRadius () {
      return this.height - constants.margin * 2
    },
    distance () {
      return px(this.width - this.height + constants.margin)
    },
    buttonStyle () {
      return {
        width: px(this.buttonRadius),
        height: px(this.buttonRadius),
        transform: this.toggled
          ? `translate3d(${this.distance}, 3px, 0px)`
          : null
      }
    },
    labelStyle () {
      return {
        lineHeight: px(this.height)
      }
    },
    colorChecked () {
      let { color } = this
      if (typeof color !== 'object') {
        return color || constants.colorChecked
      }
      return contains(color, 'checked')
        ? color.checked
        : constants.colorChecked
    },
    colorUnchecked () {
      let { color } = this
      return contains(color, 'unchecked')
        ? color.unchecked
        : constants.colorUnchecked
    },
    colorCurrent () {
      return this.toggled
        ? this.colorChecked
        : this.colorUnchecked
    },
    labelChecked () {
      return contains(this.labels, 'checked')
        ? this.labels.checked
        : constants.labelChecked
    },
    labelUnchecked () {
      return contains(this.labels, 'unchecked')
        ? this.labels.unchecked
        : constants.labelUnchecked
    }
  },
  watch: {
    value (a, b) {
      this.toggled = (typeof this.values === 'object')
        ? (a === this.values.checked)
        : !!a
    }
  },
  data () {
    return {
      focus: false,
      toggled: (typeof this.values === 'object')
        ? (this.value === this.values.checked)
        : !!this.value
    }
  },
  methods: {
    toggle (event) {
      this.toggled = !this.toggled
      let value = (typeof this.values === 'object')
        ? (this.toggled)
          ? this.values.checked
          : this.values.unchecked
        : this.value
      this.$emit('input', value)
      this.$emit('change', {
        value: value,
        srcEvent: event
      })
    }
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";

$colorChecked: $blue;
$colorUnchecked: $gray-500;
$margin: 3px;

.vue-js-switch {
  display: flex;
  align-items: center;
  position: relative;
  overflow: hidden;
  padding-top: calc(#{$input-padding-y} + #{$input-border-width});
  vertical-align: middle;
  margin: 0;
  user-select: none;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  color: rgba(0, 0, 0, 0.65);
  cursor: pointer;
  .v-switch-input {
    display: none;
  }
  .v-switch-label {
    position: absolute;
    top: 0;
    font-weight: 600;
    color: white;
    &.v-left {
      left: 10px;
    }
    &.v-right {
      right: 10px;
    }
  }
  .v-switch-core {
    display: block;
    position: relative;
    box-sizing: border-box;
    background-color: $colorUnchecked;
    outline: 0;
    margin: 0 $margin 0 0;
    transition: border-color .3s, background-color .3s;
    user-select: none;
    .v-switch-button {
      display: block;
      position: absolute;
      overflow: hidden;
      top: 0;
      left: 0;
      transition: transform 300ms;
      transform: translate3d($margin, $margin, 0);
      border-radius: 100%;
      background-color: #fff;
    }
  }

  &.disabled {
    pointer-events: none;
    opacity: 0.6;
  }
  &.toggled .v-switch-core {
    background-color: $colorChecked;
  }
}
.v-switch-wrapper {
  &.is-focus {
    .v-switch-button {
      background-color: $input-focus-border-color;
    }
  }
}
</style>
