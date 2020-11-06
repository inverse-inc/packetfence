<template>
  <div style="flex-grow: 100;">
    <b-input-group
      class="base-input-group"
      :class="{
        'is-focus': isFocus,
        'is-blur': !isFocus,
        'is-valid': state === true,
        'is-invalid': state === false
      }"
    >
      <!-- Proxy slots -->
      <template v-slot:default>
        <slot name="default"></slot>
      </template>
      <template v-slot:prepend v-if="$slots.prepend">
        <slot name="prepend"></slot>
      </template>
      <template v-slot:append v-if="$slots.append || isLocked">
        <b-button v-if="isLocked"
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
        >
          <icon ref="icon-lock"
            name="lock"
          />
        </b-button>
        <slot name="append" v-else></slot>
      </template>
    </b-input-group>
    <small v-if="text"
      v-html="text"
    />
    <small v-if="invalidFeedback"
      class="invalid-feedback"
      v-html="invalidFeedback"
    />
    <small v-if="validFeedback"
      class="valid-feedback"
      v-html="validFeedback"
    />
  </div>
</template>
<script>
export const props = {
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
    type: String
  },
  isFocus: {
    type: Boolean
  },
  isLocked: {
    type: Boolean
  }
}

// @vue/component
export default {
  name: 'base-input-group',
  inheritAttrs: false,
  props
}
</script>
<style lang="scss">
.base-input-group {
  & > div,
  & > input {
    transition: border-color .3s;
    border-top: 1px solid transparent;
    border-right: 0px;
    border-bottom: 1px solid transparent;
    border-left: 0px;

    &:first-child {
      border-top-left-radius: $border-radius !important;
      border-bottom-left-radius: $border-radius !important;
      border-left: 1px solid transparent;
    }
    &:last-child {
      border-top-right-radius: $border-radius !important;
      border-bottom-right-radius: $border-radius !important;
      border-right: 1px solid transparent;
    }
  }
  &.is-focus > div,
  &.is-focus > input {
    border-color: $input-focus-border-color !important;
  }
  &.is-invalid > div,
  &.is-invalid > input {
    border-color: $form-feedback-invalid-color !important;
  }
  &.is-valid > div,
  &.is-valid > input {
    border-color: $form-feedback-valid-color !important;
  }
}
</style>
