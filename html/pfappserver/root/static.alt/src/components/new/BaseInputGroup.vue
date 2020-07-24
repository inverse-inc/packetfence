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
        <b-button v-if="isLocked"
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
    <small v-if="inputText"
      v-html="inputText"
    />
    <small v-if="stateInvalidFeedback"
      class="invalid-feedback"
      v-html="stateInvalidFeedback"
    />
    <small v-if="stateValidFeedback"
      class="valid-feedback"
      v-html="stateValidFeedback"
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
      text,
      isLocked
    } = useInputGroup(props)

    const {
      stateMapped,
      invalidFeedback,
      validFeedback
    } = useInputValidation(props, context)

    return {
      // useInputGroup
      inputText: text,
      isLocked,

      // useInputValidation
      stateMapped,
      stateInvalidFeedback: invalidFeedback,
      stateValidFeedback: validFeedback
    }
  }
}
</script>
