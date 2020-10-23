<template>
  <div>
    <div v-if="labelLeft" class="col-form-label mr-2" v-t="label"/>
    <div
      class="base-input-range"
      :class="{
        'is-focus': isFocus,
        'is-blur': !isFocus,
        'is-disabled': isLocked,
        'size-sm': size === 'sm',
        'size-md': size === 'md',
        'size-lg': size === 'lg'
      }"
      :index="inputValue"
      :style="rootStyle"
    >
      <div style="pointer-events: none;">
        <div v-for="(hintStyle, index) in hintStyles" :key="index" class="hint" :style="hintStyle"></div>
        <span class="handle" :style="valueStyle">
          <icon v-if="isLocked" name="lock"/>
          <slot v-else/> <!-- Icon slot -->
        </span>
        <div v-if="tooltip" class="tooltip" :style="valueStyle">
          <span id="value">{{ $t(tooltipFunction(inputValue)) }}</span>
        </div>
      </div>
      <input ref="input"
        type="range"
        :tabIndex="tabIndex"
        :value="inputValue || defaultValue"
        :max="max"
        :min="min"
        :step="step"
        :disabled="isLocked"
        @change="onInput"
        @focus="onFocus"
        @blur="onBlur"
      />
    </div>
    <div v-if="labelRight" class="col-form-label ml-2" v-t="label"/>
  </div>
</template>
<script>
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useInputRange, useInputRangeProps } from '@/composables/useInputRange'

export const props = {
  label: {
    type: String
  },
  labelLeft: {
    type: Boolean
  },
  labelRight: {
    type: Boolean
  },
  step: {
    type: [String, Number],
    default: 1
  },
  tooltip: {
    type: String
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValueProps,
  ...useInputRangeProps
}

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    placeholder,
    readonly,
    tabIndex,
    text,
    type,
    isFocus,
    isLocked,
    onFocus,
    onBlur
  } = useInput(metaProps, context)

  const {
    value
  } = useInputValue(metaProps, context)

  const {
    defaultValue,
    rootStyle,
    hintStyles,
    labelStyle,
    valueStyle,
    onInput
  } = useInputRange(metaProps, context)

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputReadonly: readonly,
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
    isFocus,
    isLocked,
    onFocus,
    onBlur,

    // useInputValue
    inputValue: value,

    // useInputRange
    defaultValue,
    rootStyle,
    hintStyles,
    valueStyle,
    labelStyle,
    onInput
  }
}

// @vue/component
export default {
  name: 'base-input-range',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
:root { /* defaults */
  --range-height: 22px;
  --range-background-color: #{$input-placeholder-color};
  --range-transition-delay: 0.3s;
  --handle-height: 16px;
  --handle-background-color: var(--white);
  --handle-transition-delay: 0.3s;
  --hint-background-color: var(--light);
  --tooltip-transition-delay: 0.3s;
}

@keyframes animateHint {
  from { opacity: 0; left: 50%; width: var(--handle-height); }
  to { opacity: 0.6; }
}

.base-input-range {
  position: relative;
  height: var(--range-height);
  margin: 0px;
  box-shadow: 0 0 0 1px transparent; /* pseudo border */
  margin: 0px 1px; /* avoid pseudo border clip */
  border-radius: calc(var(--range-height) / 2);
  background-color: var(--range-background-color, $input-placeholder-color);
  text-align: left;
  transition: background-color var(--range-transition-delay) ease-out,
    box-shadow var(--range-transition-delay) ease-out,
    outline var(--range-transition-delay) ease-out;
  &.size-sm {
    --handle-height: 8px;
    --range-height: 12px;
    width: calc(var(--range-length) * 10px);
  }
  /* &.size-md { */
    --handle-height: 16px;
    --range-height: 22px;
    width: calc(var(--range-length) * 20px);
  /* } */
  &.size-lg {
    --handle-height: 32px;
    --range-height: 44px;
    width: calc(var(--range-length) * 40px);
  }
  &.is-focus {
    box-shadow: 0 0 0 1px $input-focus-border-color;
    .handle {
      box-sizing: border-box; /* inner border */
      border: 2px solid #fff;
      /*background-color: $input-focus-border-color;*/
      background-color: rgba(0, 0, 0, 1); /* [range] background-color shows through */
      animation: animateCursor 2s infinite;
    }
  }
  &.is-invalid {
    box-shadow: 0 0 0 1px $form-feedback-invalid-color;
  }
  &.is-disabled {
    background-color: var(--range-background-color, $input-disabled-bg);
    > .handle svg {
      color: var(--range-background-color, $input-disabled-bg);
    }
  }
  > div {
    position: absolute;
    right: calc(var(--range-height) / 2);
    left: calc(var(--range-height) / 2);
    height: var(--range-height);
    > .handle {
      position: absolute;
      top: calc((var(--range-height) - var(--handle-height)) / 2);
      display: flex;
      justify-content: center;
      align-items: center;
      width: var(--handle-height);
      height: var(--handle-height);
      margin-left: calc(var(--handle-height) / -2);
      border-radius: 50%;
      outline: none;
      background-color: var(--handle-background-color);
      color: var(--range-background-color, $input-placeholder-color); /* SVG icon */
      font-size: 10px;
      text-align: left;
      transition: left var(--handle-transition-delay, 0s) ease-in-out, /* do not animate `left` unless explicit */
        background-color var(--range-transition-delay) ease-out,
        color var(--range-transition-delay) ease-out;
    }
    > .hint {
      position: absolute;
      top: calc((var(--range-height) - var(--handle-height)) / 2);
      height: var(--handle-height);
      margin-left: calc(var(--handle-height) / -2);
      background-color: var(--hint-background-color);
      border-top-left-radius: var(--handle-height) 100%;
      border-bottom-left-radius: var(--handle-height) 100%;
      border-top-right-radius: var(--handle-height) 100%;
      border-bottom-right-radius: var(--handle-height) 100%;
      animation: animateHint var(--handle-transition-delay);
      transition: background-color var(--range-transition-delay) ease-out;
    }
    > .tooltip {
      position: absolute;
      bottom: calc(50% + (var(--handle-height) / 2) + 12px);
      justify-content: center;
      align-items: center;
      width: auto;
      opacity: 0;
      visibility: hidden;
      transform: translateX(-50%);
      min-width: var(--handle-height);
      font-size: .7875rem;
      text-align: center;
      transition: left var(--handle-transition-delay, 0s) ease-in-out, /* do not animate `left` unless explicit */
        width var(--handle-transition-delay, 0s) ease-in-out, /* do not animate `width` unless explicit */
        visibility var(--tooltip-transition-delay) linear,
        opacity var(--tooltip-transition-delay) ease-in-out;
      &:after { /* tooltip arrow */
        content: "";
        position: absolute;
        top: 20px;
        left: 50%;
        border-color: transparent;
        border-top-color: #000;
        border-style: solid;
        border-width: .4rem .4rem 0;
        transform: translateX(-50%);
      }
      > span { /* tooltip body */
        padding: .25rem .5rem;
        background-color: #000;
        color: #fff;
        border-radius: .25rem;
        font-family: var(--font-family-sans-serif);
        font-size: .7875rem;
        font-style: normal;
        font-weight: 400;
        line-height: 1.5;
        letter-spacing: normal;
        text-align: center;
        text-shadow: none;
        text-transform: none;
        white-space: nowrap;
        word-break: normal;
        word-spacing: normal;
        line-break: auto;
        &::selection { background: transparent; }
        &::-moz-selection { background: transparent; }
      }
    }
  }
  > input[type=range] {
    position: absolute;
    top: 0px;
    left: 0px;
    right: 0px;
    width: 100%;
    height: 100%;
    pointer-events: all;
    -webkit-appearance: none; /* disable track clicks */
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
      border: transparent;
      background: transparent;
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
      border: 0 none;
      background: transparent;
    }
    &::-ms-fill-upper {
      border: 0 none;
      background: transparent;
    }
    &::-ms-tooltip {
      display: none;
    }
  }
  > div > .hint,
  &[disabled] {
    opacity: 0.6;
  }
  &:not([disabled]) {
    &:hover > div > .tooltip {
      opacity: 1;
      visibility: visible;
    }
    cursor: pointer;
    > input[type="range"] {
      cursor: pointer;
    }
  }
}
</style>
