<template>
  <div>
    <b-input-group
      :class="{
        'is-valid': inputState === true,
        'is-invalid': inputState === false
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
    <small v-if="inputInvalidFeedback"
      class="invalid-feedback"
      v-html="inputInvalidFeedback"
    />
    <small v-if="inputValidFeedback"
      class="valid-feedback"
      v-html="inputValidFeedback"
    />
  </div>
</template>
<script>
import { useInputGroup, useInputGroupProps } from '@/composables/useInputGroup'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'

export const props = {
  ...useInputGroupProps,
  ...useInputValidatorProps
}

// @vue/component
export default {
  name: 'base-input-group',
  inheritAttrs: false,
  props,
  setup(props) {
    const {
      text,
      isLocked
    } = useInputGroup(props)

    const {
      state,
      invalidFeedback,
      validFeedback
    } = useInputValidator(props, null)

    return {
      // useInputGroup
      inputText: text,
      isLocked,

      // useInputValidator
      inputState: state,
      inputInvalidFeedback: invalidFeedback,
      inputValidFeedback: validFeedback
    }
  }
}
</script>
