<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :state="inputState"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <b-input-group
      :class="{
        'is-focus': isFocus,
        'is-blur': !isFocus,
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <multiselect ref="inputRef"
        class="base-input-chosen"
        :class="{
          'is-empty': !inputValue,
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
    <template v-slot:description v-if="inputText">
      <div v-html="inputText"/>
    </template>
    <template v-slot:invalid-feedback v-if="inputInvalidFeedback">
      <div v-html="inputInvalidFeedback"/>
    </template>
    <template v-slot:valid-feedback v-if="inputValidFeedback">
      <div v-html="inputValidFeedback"/>
    </template>
  </b-form-group>
</template>
<script>
import Multiselect from 'vue-multiselect'

const components = {
  Multiselect
}

import { computed, onBeforeUnmount, onMounted, ref, toRefs, unref } from '@vue/composition-api'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useInputMultiselectProps } from '@/composables/useInputMultiselect'

export const props = {
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,
  ...useInputMultiselectProps,

  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
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
    onInput,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    onRemove: () => {},
    singleLabel,
    bind
  }
}

// @vue/component
export default {
  name: 'base-form-group-chosen',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
