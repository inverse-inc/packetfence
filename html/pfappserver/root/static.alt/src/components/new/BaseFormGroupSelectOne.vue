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
      <multiselect ref="input"
        class="base-input-select-one"
        :class="{
          'is-empty': !inputValue,
          'size-sm': size === 'sm',
          'size-md': size === 'md',
          'size-lg': size === 'lg'
        }"

        :value="inputValue"
        :placeholder="inputPlaceholder"
:zzzloading="false"
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
zzzmax=""
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
      >
        <template v-slot:singleLabel="{ option }">
          {{ option }}
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
import { toRefs, unref } from '@vue/composition-api'
import Multiselect from 'vue-multiselect'
import useEventFnProxy from '@/composables/useEventFnProxy'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useInputMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useInputMultiselectProps } from '@/composables/useInputMultiselect'

const components = {
  Multiselect
}

export const props = {
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },

  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,
  ...useInputMultiselectProps
}

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)
  const {
    options,
    trackBy
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
  const onInputProxy = useEventFnProxy(onInput, ({ [unref(trackBy)]: trackedValue }) => trackedValue)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  return {
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

    // useEventFnProxy
    onInput: onInputProxy,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback
  }
}

// @vue/component
export default {
  name: 'base-form-group-select-one',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
