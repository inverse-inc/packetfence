<template>
  <div style="flex-grow: 100;">
    <multiselect ref="inputRef"
      class="base-input-chosen"
      :class="{
        'is-empty': !inputValue,
        'is-blur': !isFocus,
        'is-focus': isFocus,
        'is-invalid': inputState === false,
        'is-valid': inputState === true,
        'size-sm': size === 'sm',
        'size-md': size === 'md',
        'size-lg': size === 'lg'
      }"

      :value="inputValue"
      :placeholder="inputPlaceholder"
      :loading="false"
      :disabled="isLocked"
      :show-no-results="true"
      :tab-index="inputTabIndex"
      @open="onFocus"
      @close="onBlur"

      :id="id"
      :options="inputOptions"
      :multiple="multiple"
      :track-by="trackBy"
      :label="label"

      :searchable="searchable"
      :clear-on-select="clearOnSelect"
      :hide-selected="hideSelected"
      :allow-empty="allowEmpty"
      :reset-after="resetAfter"
      :close-on-select="closeOnSelect"
      :custom-label="customLabel"
      :taggable="taggable"
      :tag-placeholder="tagPlaceholder"
      :tag-position="tagPosition"
      :options-limit="optionsLimit"
      :group-values="groupValues"
      :group-label="groupLabel"
      :group-select="groupSelect"
      :internal-search="internalSearch"
      :preserve-search="preserveSearch"
      :preselect-first="preselectFirst"
      :name="name"
      :select-label="selectLabel"
      :select-group-label="selectGroupLabel"
      :selected-label="selectedLabel"
      :deselect-label="deselectLabel"
      :deselect-group-label="deselectGroupLabel"
      :show-labels="showLabels"
      :limit="limit"
      :limit-text="limitText"
      :open-direction="openDirection"
      :show-pointer="showPointer"
      @select="onInput"
      @remove="onRemove"
      @tag="onTag"

      v-bind="bind"
    >
      <template v-slot:singleLabel>
        {{ singleLabel }}
      </template>
      <template v-slot:tag="{ option }">
        <span class="multiselect__tag bg-secondary">
          <span>{{ option[label] }}</span>
          <i aria-hidden="true" tabindex="1" class="multiselect__tag-icon" @click="onRemove(option)"></i>
        </span>
      </template>
      <template v-slot:beforeList>
        <li class="multiselect__element">
          <div class="col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">{{ $t('Type to filter results') }}</div>
        </li>
      </template>
      <template v-slot:noOptions>
        <b-media class="text-secondary" md="auto">
          <template v-slot:aside><icon name="search" scale="1.5" class="mt-2 ml-2"></icon></template>
          <strong>{{ $t('No options') }}</strong>
          <b-form-text class="font-weight-light">{{ $t('List is empty.') }}</b-form-text>
        </b-media>
      </template>
      <template v-slot:noResult>
        <b-media class="text-secondary" md="auto">
          <template v-slot:aside><icon name="search" scale="1.5" class="mt-2 ml-2"></icon></template>
          <strong>{{ $t('No results') }}</strong>
          <b-form-text class="font-weight-light">{{ $t('Please refine your search.') }}</b-form-text>
        </b-media>
      </template>
    </multiselect>
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
import { computed, nextTick, onBeforeUnmount, onMounted, ref, toRefs, unref } from '@vue/composition-api'
import Multiselect from 'vue-multiselect'

const components = {
  Multiselect
}

import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useInputMultiselectProps } from '@/composables/useInputMultiselect'

export const props = {
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },

  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,
  ...useInputMultiselectProps
}

export const setup = (props, context) => {

  // template refs
  const inputRef = ref(null)

  // stopPropagation w/ Escape keydown
  const inputKeyDownHandler = e => {
    const { keyCode } = e
    switch (keyCode) {
      case 27: // Escape
        e.stopPropagation()
        break
    }
  }
  onMounted(() => {
    for (let input of inputRef.value.$el.querySelectorAll('input')) {
      const removeKeyDownEvent = () => input && input.removeEventListener('keydown', inputKeyDownHandler)
      input.addEventListener('keydown', inputKeyDownHandler)
      onBeforeUnmount(removeKeyDownEvent)
    }
  })

  const metaProps = useInputMeta(props, context)
  const {
    label,
    trackBy,
    options,
    max,
    multiple
  } = toRefs(metaProps)

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
    value,
    onInput
  } = useInputValue(metaProps, context)
  const onInputWrapper = useEventFnWrapper(onInput, value => {
    const { [unref(trackBy)]: trackedValue } = value
    return trackedValue
  })

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  const singleLabel = computed(() => {
    const _options = unref(options)
    const optionsIndex = _options.findIndex(option => {
      const { [unref(trackBy)]: trackedValue } = option
      return trackedValue === unref(value)
    })
    if (optionsIndex > -1)
      return _options[optionsIndex][unref(label)]
    else
      return unref(value)
  })

  // supress warning:
  //  [Vue-Multiselect warn]: Max prop should not be used when prop Multiple equals false.
  const bind = computed(() => {
    return (unref(multiple))
      ? { max: max.value }
      : {}
  })

  const doFocus = () => nextTick(() => context.refs.inputRef.$el.focus())
  const doBlur = () => nextTick(() => context.refs.inputRef.$el.blur())

  return {
    inputRef,

    // useInputMeta
    inputOptions: options,

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

    // useEventFnWrapper
    onInput: onInputWrapper,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    onRemove: () => {},
    onTag: () => {},
    singleLabel,
    bind,
    doFocus,
    doBlur
  }
}

// @vue/component
export default {
  name: 'base-input-chosen',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
/**
 * Adjust is-invalid and is-focus borders
 */
.base-input-chosen {

  /* show placeholder even when empty */
  &.is-empty {
    .multiselect__input,
    .multiselect__placeholder {
      position: relative !important;
      width: 100% !important;
    }
    .multiselect__placeholder {
      display: none;
    }
  }
  &.is-empty:not(.is-focus) {
    .multiselect__single {
      display: none;
    }
  }

  .multiselect__loading-enter-active,
  .multiselect__loading-leave-active,
  .multiselect__input,
  .multiselect__single,
  .multiselect__tags,
  .multiselect__tag-icon,
  .multiselect__select,
  .multiselect-enter-active,.multiselect-leave-active {
    transition: $custom-forms-transition;
  }
  .multiselect__option:after {
    font-weight: $font-weight-light;
  }
  .multiselect__option[data-select=""].multiselect__option--highlight:after,
  .multiselect__option[data-deselect=""].multiselect__option--highlight:after {
    height: 100%;
    background: none;
    font-size: .7875rem;
    font-weight: 500;
    line-height: 1.71429;
  }
  .multiselect__tags {
    padding-right: 40px;
    border: 1px solid $input-focus-bg;
    background-color: $input-focus-bg;
    outline: 0;
    .multiselect__input {
      max-width: 100%;
    }
    span > span.multiselect__single { /* placeholder */
      color: $input-placeholder-color;
      // override Firefox's unusual default opacity; see https://github.com/twbs/bootstrap/pull/11526.
      opacity: 1;
    }
  }
  .multiselect__select {
    top: 0px;
    /*right: 10px;*/
    bottom: 0px;
    width: auto;
    height: auto;
    padding: 0px;
  }
  .multiselect__tag {
    margin-bottom: 0px;
    background-color: $secondary;
  }
  .multiselect__tag-icon {
    line-height: 1;
    background-color: inherit;
    color: inherit;
    &:hover {
      color: lighten($secondary, 15%);
    }
    &:after {
      color: $component-active-color;
      font-size: inherit;
      line-height: 1.5;
    }
  }
  .multiselect__input,
  .multiselect__single {
    overflow: hidden;
    padding: 0px;
    margin: 0px;
    background-color: transparent;
    color: $input-color;
    white-space: nowrap;
    &::placeholder {
      color: $input-placeholder-color;
    }
    // override multiselect's absolute height
    line-height: inherit;
  }
  .multiselect__placeholder {
    padding-top: 0px;
    padding-bottom: 0px;
    margin-bottom: 0px;
    color: $input-placeholder-color;
    font-size: $font-size-base;
    line-height: $input-line-height;
  }
  .multiselect__spinner {
    right: 2 * $input-btn-padding-x;
    background-color: transparent;
  }
  .multiselect__content-wrapper {
    z-index: $zindex-popover;
    border: $dropdown-border-width solid $dropdown-border-color;
    @include border-radius($dropdown-border-radius);
    @include box-shadow($dropdown-box-shadow);
    .col-form-label {
      font-size: 80%!important;
    }
  }
  .multiselect--active:not(.multiselect--above) {
    .multiselect__content-wrapper {
      border-top-width: 0px;
      border-bottom-width: 1px;
      border-top-left-radius: 0 !important;
      border-top-right-radius: 0 !important;
      border-bottom-left-radius: $border-radius !important;
      border-bottom-right-radius: $border-radius !important;
    }
  }
  .multiselect--above {
    .multiselect__content-wrapper {
      border-bottom-width: 0px;
      border-bottom-left-radius: 0 !important;
      border-bottom-right-radius: 0 !important;
    }
  }
  .multiselect__option--group {
    background-color: var(--secondary) !important;
    color: var(--white) !important;
    font-size: .7875rem;
    font-weight: 800;
    line-height: 1.71429;
  }
  .multiselect__option--highlight {
    background-color: var(--primary);
    color: $dropdown-link-active-color;
    &:after,
    &:hover {
      background-color: var(--primary);
      color: var(--white) !important;
    }
  }

  &.multiselect {
    flex: 1 1 auto;
    width: auto;
    min-height: auto;
  }
  &.multiselect--disabled {
    background-color: $input-disabled-bg;
    opacity: 1;
    .multiselect__tags,
    .multiselect__single {
      background-color: $input-disabled-bg;
    }
    .multiselect__select {
      background-color: transparent;
    }
  }
  .input-group-text {
    border: none;
  }
  &.size-sm {
    .multiselect,
    .multiselect__input,
    .multiselect__single,
    .btn .fa-icon {
      font-size: $font-size-sm;
    }
    .multiselect__tags {
      @include border-radius($border-radius-sm);
      padding: $input-padding-y-sm $input-padding-x-sm 0 $input-padding-x-sm;
    }
    &.multiselect--active .multiselect__tags {
      padding: $input-padding-y-sm $input-padding-x-sm;
    }
    .multiselect__tags,
    .multiselect__option,
    .multiselect__option:after {
      min-height: $input-height-sm;
      font-size: $font-size-sm;
    }
    .multiselect__option,
    .multiselect__option:after {
      line-height: $input-line-height-sm;
      padding: $input-padding-y-sm $input-padding-x-sm;
    }
    .multiselect__select {
      right: $input-padding-x-sm
    }
    .multiselect__single {
      margin-right: $input-padding-x-sm;
      padding-right: $input-padding-x-sm;
    }
  }
  &.size-md {
    .multiselect,
    .multiselect__input,
    .multiselect__single,
    .btn .fa-icon {
      font-size: $font-size-base;
    }
    .multiselect__tags {
      @include border-radius($border-radius);
      padding: $input-padding-y $input-padding-x 0 $input-padding-x;
    }
    &.multiselect--active .multiselect__tags {
      padding: $input-padding-y $input-padding-x;
    }
    .multiselect__tags,
    .multiselect__option,
    .multiselect__option:after {
      min-height: $input-height;
      font-size: $font-size-base;
    }
    .multiselect__option,
    .multiselect__option:after {
      line-height: $input-line-height;
      padding: $input-padding-y $input-padding-x;
    }
    .multiselect__select {
      right: $input-padding-x
    }
    .multiselect__single {
      margin-right: $input-padding-x;
      padding-right: $input-padding-x;
    }
  }
  &.size-lg {
    .multiselect,
    .multiselect__input,
    .multiselect__single,
    .btn .fa-icon {
      font-size: $font-size-lg;
    }
    .multiselect__tags {
      @include border-radius($border-radius-lg);
      padding: $input-padding-y-lg $input-padding-x-lg 0 $input-padding-x-lg;
    }
    &.multiselect--active .multiselect__tags {
      padding: $input-padding-y-lg $input-padding-x-lg;
    }
    .multiselect__tags,
    .multiselect__option,
    .multiselect__option:after {
      min-height: $input-height-lg;
      font-size: $font-size-lg;
    }
    .multiselect__option,
    .multiselect__option:after {
      line-height: $input-line-height-lg;
      padding: $input-padding-y-lg $input-padding-x-lg;
    }
    .multiselect__select {
      right: $input-padding-x-lg
    }
    .multiselect__single {
      margin-right: $input-padding-x-lg;
      padding-right: $input-padding-x-lg;
    }
  }
}

.input-group.is-focus > .base-input-select,
.base-input-select.is-focus {
  .multiselect__tags {
    border-color: $input-focus-border-color;
  }
  .multiselect__select:before {
    color: $input-focus-border-color;
    border-color: $input-focus-border-color transparent transparent;
  }
}
.input-group.is-invalid > .base-input-select,
.base-input-select.is-invalid {
  .multiselect__tags {
    border-color: $form-feedback-invalid-color;
  }
  .multiselect__select:before {
    color: $form-feedback-invalid-color;
    border-color: $form-feedback-invalid-color transparent transparent;
  }
}
.input-group.is-valid > .base-input-select,
.base-input-select.is-valid {
  .multiselect__tags {
    border-color: $form-feedback-valid-color;
  }
  .multiselect__select:before {
    color: $form-feedback-valid-color;
    border-color: $form-feedback-valid-color transparent transparent;
  }
}

</style>
