<template>
  <div slider id="slider-distance" :style="{
    '--range-height': `${rangeHeight}px`,
    '--thumb-height': `${thumbHeight}px`,
    '--transition-delay': `${transitionDelay}s`
  }">
    <div>
      <div inverse :style="{ width: `(100 - ${percent})%` }"></div>
      <div range :style="{ width: `${percent}%` }"></div>
      <span thumb :style="{ left: `${percent}%` }"><slot/></span>
      <div sign :style="{ left: `${percent}%` }">
        <span id="value">{{ labelFunction(inputValue) }}</span>
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
      @input="inputValue = $event.target.value"
    />
  </div>
</template>

<script>
export default {
  name: 'pf-slider',
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
    rangeHeight: {
      type: Number,
      default: 22
    },
    thumbHeight: {
      type: Number,
      default: 16
    },
    transitionDelay: {
      type: Number,
      default: 0.3
    },
    labelFunction: {
      type: Function,
      default: (value) => { return value }
    }
  },
  data () {},
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    },
    percent () {
      return (100 / (this.max - this.min)) * parseInt(this.inputValue) - (100 / (this.max - this.min)) * this.min
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  }
}
</script>

<style lang="scss">
:root {
 --range-height: 22px;
 --thumb-height: 16px;
 --transition-delay: 0.3s;
}
[slider] {
  position: relative;
  height: var(--range-height);
  border-radius: calc(var(--range-height) / 2);
  background-color: #ff0000;
  text-align: left;
  margin: 0px;
  > div {
    position: absolute;
    left: calc(var(--range-height) / 2);
    right: calc(var(--range-height) / 2);
    height: var(--range-height);
    > [zzzrange] {
      position: absolute;
      left: 0;
      height: var(--range-height);
      border-top-left-radius: calc(var(--range-height) / 2);
      border-bottom-left-radius: calc(var(--range-height) / 2);
      background-color: #ff6600;
    }
    > [zzzinverse] {
      position: absolute;
      right: 0;
      height: var(--range-height);
      border-top-right-radius: calc(var(--range-height) / 2);
      border-bottom-right-radius: calc(var(--range-height) / 2);
      background-color: #CCC;
    }
    > [thumb] {
      position: absolute;
      top: calc((var(--range-height) - var(--thumb-height)) / 2);
      z-index: 2;
      height: var(--thumb-height);
      width: var(--thumb-height);
      text-align: left;
      margin-left: calc(var(--thumb-height) / -2);
      cursor: pointer;
      box-shadow: 0 3px 8px rgba(0, 0, 0, 0.4);
      background-color: #ffffff;
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
    > [sign] {
      opacity: 0;
      visibility: hidden;
      -webkit-transition: visibility var(--transition-delay), opacity var(--transition-delay) ease-in-out;
      -moz-transition: visibility var(--transition-delay), opacity var(--transition-delay) ease-in-out;
      -ms-transition: visibility var(--transition-delay), opacity var(--transition-delay) ease-in-out;
      -o-transition: visibility var(--transition-delay), opacity var(--transition-delay) ease-in-out;
      transition: visibility var(--transition-delay), opacity var(--transition-delay) ease-in-out;
      position: absolute;
      transform: translateX(-50%);
      top: -39px;
      z-index:3;
      min-width: 28px;
      width: auto;
      height: 28px;
      align-items: center;
      -webkit-justify-content: center;
      justify-content: center;
      text-align: center;
      &:after {
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
        font-family: -apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;
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
    /* Change to none to disable track clicks */
    -webkit-appearance: none;
    z-index: 3;
    height: var(--range-height);
    top: -2px;
    left: calc(var(--range-height) / 2);
    right: calc(var(--range-height) / 2);
    width: calc(100% - var(--range-height));
    -ms-filter: "progid:DXImageTransform.Microsoft.Alpha(Opacity=0)";
    filter: alpha(opacity=0);
    -moz-opacity: 0;
    -khtml-opacity: 0;
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
      width: 28px;
      height: 28px;
      border-radius: 0px;
      border: 0 none;
      background: red;
    }
    &::-moz-range-thumb {
      pointer-events: all;
      width: 28px;
      height: 28px;
      border-radius: 0px;
      border: 0 none;
      background: red;
    }
    &::-webkit-slider-thumb {
      pointer-events: all;
      width: 28px;
      height: 28px;
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
  &:hover > div > [sign] {
    opacity: 1;
    visibility: visible;
  }
}
</style>
