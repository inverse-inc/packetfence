<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :content-cols="contentCols"
    :content-cols-md="contentColsMd"
    :content-cols-lg="contentColsLg"
    :content-cols-xl="contentColsXl"
    :state="state"
    :label="columnLabel"
    :label-class="labelClass"
    :label-cols="labelCols"
    :label-cols-md="labelColsMd"
    :label-cols-lg="labelColsLg"
    :label-cols-xl="labelColsXl"
  >
    <template v-slot:description v-if="apiFeedback">
      <div v-html="apiFeedback" class="text-warning"/>
    </template>
    <template v-slot:invalid-feedback v-if="invalidFeedback">
      <span v-html="invalidFeedback" />
    </template>
    <template v-slot:valid-feedback v-if="validFeedback">
      <span v-html="validFeedback" />
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
        <slot v-if="!disabled"
         name="append"></slot>
        <b-button v-else
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
  apiFeedback: {
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
<style lang="scss" scoped>
.base-form-group {
  .input-group {
    margin-bottom: 0;
  }
}
</style>
<style lang="scss">
.base-form-group {
  .col {
    align-self: center !important;
    .input-group {
      .input-group-append,
      .input-group-prepend {
        height: auto;
      }
    }
  }
}
</style>
