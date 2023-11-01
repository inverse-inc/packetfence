<template>
  <div class="base-input-switch-wrapper">
    <div
      class="base-input-switch"
      :class="{
        'is-focus': focus,
        'is-disabled': isLocked,
        'size-sm': size === 'sm',
        'size-md': size === 'md',
        'size-lg': size === 'lg',
        'switch-enabled' : rangeValue === 1,
      }"
      :index="value"
      @click.stop
    >
      <div style="pointer-events: none;">
        <span :class="[
          'handle',
          rangeValue === 1 ? 'handle-on' : 'handle-off'
        ]">
          <icon v-if="isLocked" name="lock"/>
          <icon v-else-if="icon" :name="icon"/>
          <slot v-else/> <!-- Icon slot -->
        </span>
      </div>
      <input type="range" ref="input"
             v-bind="$attrs"
             :tabIndex="tabIndex"
             :value="rangeValue"
             :step="1"
             :max="1"
             :min="0"
             :disabled="isLocked"
             @focus="() => setFocus(true)"
             @focusout="() => setFocus(false)"
             @mouseup="onClick"
      />
    </div>
  </div>
</template>
<script>
import {useInputProps} from '@/composables/useInput'
import {useInputValidatorProps} from '@/composables/useInputValidator'
import {computed, ref, unref} from '@vue/composition-api';

export const useSwitchProps = {
  onChange: {
    type: Function
  },
  isLocked: {
    default: false,
    type: Boolean
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  value: {
    default: false
  },
  icon: {
    type: String
  },
}

export const props = {
  ...useInputProps,
  ...useInputValidatorProps,
  ...useSwitchProps,
}

export const setup = (props) => {

  const rangeValue = computed(() => {
    return props.value ? 1 : 0
  })

  const focus = ref(false)
  const setFocus = (focusVal) => {
    focus.value = focusVal
  }

  const toggle = () => {
    if (unref(rangeValue) === 1) {
      props.onChange(false)
    } else {
      props.onChange(true)
    }
  }

  return {
    rangeValue,
    onClick: toggle,
    focus,
    setFocus,
  }
}

// @vue/component
export default {
  name: 'base-input-switch',
  inheritAttrs: false,
  props,
  setup
}
</script>

<style lang="scss">

:root {
  --range-length: 2;
  --range-height: 22px;
  --range-background-color: #{$input-placeholder-color};
  --range-transition-delay: 0.3s;
  --handle-height: 16px;
  --handle-background-color: var(--white);
  --handle-transition-delay: 0.3s;
}

.base-input-switch {
  position: relative;
  flex-shrink: 0;
  height: var(--range-height);
  margin: 0px;
  box-shadow: 0 0 0 1px transparent;
  margin: 0px 1px;
  border-radius: calc(var(--range-height) / 2);
  background-color: var(--range-background-color, #adb5bd);
  text-align: left;
  transition: background-color var(--range-transition-delay) ease-out, box-shadow var(--range-transition-delay) ease-out, outline var(--range-transition-delay) ease-out;
  --handle-height: 16px;
  --range-height: 22px;
  width: calc(var(--range-length) * 20px);
}

div.base-input-switch-wrapper {
  display: flex;
  border: none;
}

.base-input-switch .handle-on {
  left: 100%;
}

.base-input-switch .handle-off {
  left: 0;
}

div.base-input-switch.switch-enabled {
  background-color: var(--primary);
}

.base-input-switch {
  position: relative;
  flex-shrink: 0;
  height: var(--range-height);
  margin: 0px;
  box-shadow: 0 0 0 1px transparent;
  margin: 0px 1px;
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

  --handle-height: 16px;
  --range-height: 22px;
  width: calc(var(--range-length) * 20px);

  &.size-lg {
    --handle-height: 32px;
    --range-height: 44px;
    width: calc(var(--range-length) * 40px);
  }

  &.is-focus {
    box-shadow: 0 0 0 1px $input-focus-border-color;

    .handle {
      box-sizing: border-box;
      border: 2px solid #fff;
      background-color: rgba(0, 0, 0, 1);
      animation: animateCursor 2s infinite;
    }
  }

  &.is-invalid {
    box-shadow: 0 0 0 1px $form-feedback-invalid-color;
  }

  &.is-disabled {
    background-color: var(--range-background-color, $input-disabled-bg);
    opacity: 0.6;

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
      transition: left var(--handle-transition-delay, 0s) ease-in-out,
      background-color var(--range-transition-delay) ease-out,
      color var(--range-transition-delay) ease-out;
    }
  }

  > input[type=range] {
    position: absolute;
    top: 0px;
    right: 0px;
    left: 0px;
    width: 100%;
    height: 100%;
    pointer-events: all;
    -webkit-appearance: none;
    opacity: 0;
  }
}
</style>
