<template>
  <fragment>
    <b-input-group
      :class="{
        'is-valid': stateMapped === true,
        'is-invalid': stateMapped === false
      }"
    >
      <!-- Proxy slots -->
      <template v-slot:default>
        <slot name="default"></slot>
      </template>
      <template v-slot:prepend>
        <slot name="prepend"></slot>
      </template>
      <template v-slot:append>
        <slot name="append"></slot>
      </template>
    </b-input-group>
    <small v-if="stateInvalidFeedback"
      class="invalid-feedback"
      v-html="stateInvalidFeedback"
    />
    <small v-if="stateValidFeedback"
      class="valid-feedback"
      v-html="stateValidFeedback"
    />
    <small v-if="inputText"
      v-html="inputText"
    />
  </fragment>
</template>
<script>
import { useInputGroup, useInputGroupProps } from '@/composables/useInputGroup'
import { useInputValidation, useInputValidationProps } from '@/composables/useInputValidation'

export const props = {
  ...useInputGroupProps,
  ...useInputValidationProps
}

// @vue/component
export default {
  name: 'base-input-group',
  inheritAttrs: false,
  props,
  setup(props, context) {
    const {
      text
    } = useInputGroup(props)

    const {
      stateMapped,
      invalidFeedback,
      validFeedback
    } = useInputValidation(props, context)

    return {
      // useInputGroup
      inputText: text,

      // useInputValidation
      stateMapped,
      stateInvalidFeedback: invalidFeedback,
      stateValidFeedback: validFeedback
    }
  }
}
</script>
