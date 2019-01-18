<template>
  <div style="width:100%"> <!-- external style applied here -->
    <div range id="range"
      :style="{
        '--border-color': borderColor,
        '--border-width': `${borderWidth}px`,
        '--range-height': `${rangeHeight}px`,
        '--range-background-color': rangeBackgroundColor,
        '--range-transition-delay': `${rangeTransitionDelay}s`,
        '--handle-height': `${handleHeight}px`,
        '--handle-background-color': handleBackgroundColor,
        '--handle-transition-delay': `${handleTransitionDelay}s`,
        '--hint-background-color': hintBackgroundColor,
        '--tooltip-transition-delay': `${tooltipTransitionDelay}s`
      }"
      :class="{
        'disabled': disabled,
        'enabled': !disabled,
        'min': parseFloat(inputValue) === parseFloat(min),
        'max': parseFloat(inputValue) === parseFloat(max)
      }"
    >
      <div>
        <div hint v-for="(hint, index) in hints" :key="index" :style="hintStyle(index)"></div>
        <span handle :style="{ left: `${percent(inputValue)}%` }">
          <slot/>
        </span>
        <div tooltip :style="{ left: `${percent(inputValue)}%` }">
          <span id="value">{{ tooltipFunction(inputValue) }}</span>
        </div>
      </div>
      <input
        v-on="forwardListeners"
        type="range"
        :tabindex="tabIndex"
        :value="inputValue"
        :max="max"
        :min="min"
        :step="step"
        :disabled="disabled"
        @input="inputValue = $event.target.value"
      />
      <div catch-min @click="inputValue = min"><!-- catch left-side clicks outside input --></div>
      <div catch-max @click="inputValue = max"><!-- catch right-side clicks outside input --></div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'input-range',
  props: {
    value: {
      type: Number,
      default: null
    },
    tabIndex: {
      type: Number,
      default: 0
    },
    min: {
      type: Number,
      default: 0
    },
    max: {
      type: Number,
      default: 100
    },
    step: {
      type: Number,
      default: 1
    },
    disabled: {
      type: Boolean,
      default: false
    },
    borderColor: {
      type: String,
      default: 'transparent'
    },
    borderWidth: {
      type: Number,
      default: 0
    },
    rangeHeight: {
      type: Number,
      default: 22
    },
    rangeBackgroundColor: {
      type: String,
      default: '#adb5bd'
    },
    rangeTransitionDelay: {
      type: Number,
      default: 0.3
    },
    handleHeight: {
      type: Number,
      default: 16
    },
    handleBackgroundColor: {
      type: String,
      value: '#ffffff'
    },
    handleTransitionDelay: {
      type: Number,
      default: 0
    },
    hintBackgroundColor: {
      type: String,
      default: '#ffffff'
    },
    tooltipTransitionDelay: {
      type: Number,
      default: 0.3
    },
    tooltipFunction: {
      type: Function,
      default: (value) => { return value }
    },
    hints: {
      type: Array,
      default: () => { return [] }
    }
  },
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    percent (value = this.inputValue) {
      return (100 / (this.max - this.min)) * parseInt(value) - (100 / (this.max - this.min)) * this.min
    },
    hintStyle (index) {
      let style = {}
      if (index in this.hints) {
        const hint = this.hints[index]
        if (hint.constructor === Array) { // range
          style.left = `${this.percent(hint[0])}%`
          style.width = `calc(${this.percent(hint[1] - hint[0])}% + var(--handle-height))`
        } else { // single
          style.left = `${this.percent(hint)}%`
          style.width = 'var(--handle-height)'
        }
        return style
      }
    }
  }
}
</script>

<style lang="scss" scoped>
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";
@import "../../node_modules/bootstrap/scss/root";

:root {
 --border-color: transparent;
 --border-width: 0px;
 --range-height: 22px;
 --range-background-color: #adb5bd;
 --range-transition-delay: 0.3s;
 --handle-height: 16px;
 --handle-background-color: #ffffff;
 --handle-transition-delay: 0s;
 --hint-background-color: #ffffff;
 --tooltip-transition-delay: 0.3s;
}

[range] {
  position: relative;
  height: var(--range-height);
  box-shadow: 0 0 0 var(--border-width) var(--border-color); /* pseudo border */
  border-radius: calc(var(--range-height) / 2);
  background-color: var(--range-background-color);
  text-align: left;
  margin: 0px;
  transition: background-color var(--range-transition-delay) ease-out, outline var(--range-transition-delay) ease-out;
  > div {
    position: absolute;
    left: calc(var(--range-height) / 2);
    right: calc(var(--range-height) / 2);
    height: var(--range-height);
    > [handle] {
      transition: left var(--handle-transition-delay) ease-in-out;
      position: absolute;
      top: calc((var(--range-height) - var(--handle-height)) / 2);
      height: var(--handle-height);
      width: var(--handle-height);
      text-align: left;
      margin-left: calc(var(--handle-height) / -2);
      background-color: var(--handle-background-color);
      border-radius: 50%;
      outline: none;
      display: -webkit-box;
      display: -moz-box;
      display: -ms-flexbox;
      display: -webkit-flex;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    > [hint] {
      position: absolute;
      top: calc((var(--range-height) - var(--handle-height)) / 2);
      height: var(--handle-height);
      margin-left: calc(var(--handle-height) / -2);
      background-color: var(--hint-background-color);
      border-top-left-radius: var(--handle-height) 100%;
      border-bottom-left-radius: var(--handle-height) 100%;
      border-top-right-radius: var(--handle-height) 100%;
      border-bottom-right-radius: var(--handle-height) 100%;
    }
    > [tooltip] {
      opacity: 0;
      visibility: hidden;
      transition: left var(--handle-transition-delay) ease-in-out, visibility var(--tooltip-transition-delay) linear, opacity var(--tooltip-transition-delay) ease-in-out;
      position: absolute;
      transform: translateX(-50%);
      bottom: calc(50% + (var(--handle-height) / 2) + 8px);
      min-width: var(--handle-height);
      width: auto;
      align-items: center;
      -webkit-justify-content: center;
      justify-content: center;
      text-align: center;
      &:after { /* tooltip arrow */
        position: absolute;
        content: "";
        border-color: transparent;
        border-style: solid;
        top: 22px;
        left: 50%;
        transform: translateX(-50%);
        border-width: .4rem .4rem 0;
        border-top-color: #000;
      }
      > span {
        padding: .25rem .5rem;
        color: #fff;
        text-align: center;
        background-color: #000;
        border-radius: .25rem;
        font-family: var(--font-family-sans-serif);
        font-style: normal;
        font-weight: 400;
        line-height: 1.5;
        text-shadow: none;
        text-transform: none;
        letter-spacing: normal;
        word-break: normal;
        word-spacing: normal;
        white-space: nowrap;
        line-break: auto;
        font-size: .7875rem;
        &::selection { background: transparent; }
        &::-moz-selection { background: transparent; }
      }
    }
  }
  > input[type=range] {
    position: absolute;
    pointer-events: all;
    -webkit-appearance: none; /* disable track clicks */
    height: var(--handle-height);
    top: calc((var(--range-height) - var(--handle-height)) / 2);
    left: calc(var(--range-height) / 2);
    right: calc(var(--range-height) / 2);
    width: calc(100% - var(--range-height));
    opacity: 0;
    &::-ms-track {
      -webkit-appearance: none;
      background: transparent;
      color: transparent;
    }
    &::-moz-range-track {
      -moz-appearance: none;
      background: transparent;
      color: transparent;
    }
    &:focus::-webkit-slider-runnable-track {
      background: transparent;
      border: transparent;
    }
    &:focus {
      outline: none;
    }
    &::-ms-thumb {
      pointer-events: all;
      width: var(--range-height);
      height: var(--range-height);
      border-radius: 0px;
      border: 0 none;
      background: red;
    }
    &::-moz-range-thumb {
      pointer-events: all;
      width: var(--range-height);
      height: var(--range-height);
      border-radius: 0px;
      border: 0 none;
      background: red;
    }
    &::-webkit-slider-thumb {
      pointer-events: all;
      width: var(--range-height);
      height: var(--range-height);
      border-radius: 0px;
      border: 0 none;
      background: red;
      -webkit-appearance: none;
    }
    &::-ms-fill-lower {
      background: transparent;
      border: 0 none;
    }
    &::-ms-fill-upper {
      background: transparent;
      border: 0 none;
    }
    &::-ms-tooltip {
      display: none;
    }
  }
  > [catch-min] {
    position: absolute;
    left: 0px;
    top: calc((var(--range-height) - var(--handle-height)) / 2);
    height: var(--handle-height);
    width: calc(var(--range-height) / 2);
  }
  > [catch-max] {
    position: absolute;
    left: calc(100% - (var(--range-height) / 2));
    top: calc((var(--range-height) - var(--handle-height)) / 2);
    height: var(--handle-height);
    width: calc(var(--range-height) / 2);
  }
  > div > [hint],
  &.disabled {
    opacity: 0.6;
  }
  &.enabled {
    &:not(.min) > [catch-min] {
      cursor: move; /* fallback if w-resize cursor is unsupported */
      cursor: w-resize;
    }
    &:not(.max) > [catch-max] {
      cursor: move; /* fallback if e-resize cursor is unsupported */
      cursor: e-resize;
    }
    &:hover > div > [tooltip] {
      opacity: 1;
      visibility: visible;
    }
    > input[type="range"] {
      cursor: move; /* fallback if grab cursor is unsupported */
      cursor: grab;
      cursor: -moz-grab;
      cursor: -webkit-grab;
    }
  }
}
</style>
