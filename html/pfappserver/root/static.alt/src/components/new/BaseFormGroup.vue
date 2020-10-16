<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel,
    }"
    :state="state"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <template v-slot:invalid-feedback>
      {{ invalidFeedback }}
    </template>
    <template v-slot:valid-feedback>
      {{ validFeedback }}
    </template>
    <b-input-group
      class="is-borders"
      :class="{
        'is-valid': state === true,
        'is-invalid': state === false,
        'is-blur': !isFocus,
        'is-focus': isFocus
      }"
    >
      <!-- Proxy slots -->
      <template v-slot:default>
        <slot/>
      </template>
      <template v-slot:prepend v-if="$slots.prepend">
        <slot name="prepend"></slot>
      </template>
      <template v-slot:append v-if="$slots.append || disabled">
        <slot name="append"></slot>
        <b-button v-if="disabled"
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
        >
          <icon ref="icon-lock"
            name="lock"
          />
        </b-button>
      </template>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>
<script>
import { useFormGroupProps } from '@/composables/useFormGroup'

export const props = {
  ...useFormGroupProps,

  isFocus: {
    type: Boolean,
    default: false
  },
  disabled: {
    type: Boolean,
    default: false
  },
  state: {
    type: Boolean,
    default: null
  },
  invalidFeedback: {
    type: String,
    default: undefined
  },
  validFeedback: {
    type: String,
    default: undefined
  },
  text: {
    type: String,
    default: undefined
  }
}

// @vue/component
export default {
  name: 'base-form-group',
  inheritAttrs: false,
  props
}
</script>
