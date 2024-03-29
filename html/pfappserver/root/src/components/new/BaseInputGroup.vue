<template>
  <div>
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
  textFn: {
    type: Function
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
.base-input-group,
.input-group {
  & > div:not([class*="base-input"]),
  & > input,
  & > .input-group-append,
  & > .input-group-prepend {
    transition: border-color .3s;
    border-top: 1px solid $input-border-color;
    border-bottom: 1px solid $input-border-color;
    &:not(:first-child) {
      border-left: 0px;
    }
    &:first-child {
      border-top-left-radius: $border-radius !important;
      border-bottom-left-radius: $border-radius !important;
      &:not(:focus) {
        border-left: 1px solid $input-border-color;
      }
    }
    &:not(:last-child) {
      border-right: 0px;
    }
    &:last-child {
      border-top-right-radius: $border-radius !important;
      border-bottom-right-radius: $border-radius !important;
      &:not(:focus) {
        border-right: 1px solid $input-border-color;
      }
    }
    & + input {
      border-left: 1px solid $input-border-color;
    }
  }
  &.is-focus > div,
  &.is-focus > input,
  &.is-focus > textarea {
    border-color: $input-focus-border-color !important;
  }
  &.is-focus .btn > .fa-icon {
    color: $input-focus-border-color;
  }
  &.is-invalid > div,
  &.is-invalid > input,
  &.is-invalid > textarea {
    border-color: $form-feedback-invalid-color !important;
  }
  &.is-invalid .btn > .fa-icon {
    color: $form-feedback-invalid-color;
  }
  &.is-valid > div,
  &.is-valid > input,
  &.is-valid > textarea {
    border-color: $form-feedback-valid-color !important;
  }
  &.is-valid .btn > .fa-icon {
    color: $form-feedback-valid-color;
  }
  &.is-blur > .input-group-append,
  &.is-blur > .input-group-prepend {
    border-color: $input-border-color;
  }
  & > .input-group-append,
  & > .input-group-prepend {
    max-height: calc(1.5em + 0.75rem + 2px);
    & .btn {
      padding: 0 0.75rem;
    }
  }
}
</style>
