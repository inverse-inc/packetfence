<template>
  <div class="base-input-chosen-container">
    <multiselect ref="inputRef"
      class="base-input-chosen"
      :class="{
        'is-empty': isEmpty,
        'is-blur': !isFocus,
        'is-focus': isFocus,
        'is-invalid': inputState === false,
        'is-valid': inputState === true,
        'size-sm': size === 'sm',
        'size-md': size === 'md',
        'size-lg': size === 'lg'
      }"
      :data-namespace="namespace"
      :data-chosen="true"

      :value="inputValue"
      :placeholder="inputPlaceholder"
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
      :group-values="inputGroupValues"
      :group-label="inputGroupLabel"

      :searchable="searchable"
      :loading="isLoading"

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
      @search-change="onSearch"

      v-bind="bind"
    >
      <template v-slot:singleLabel>
        {{ singleLabel }}
      </template>
      <template v-slot:tag="{ option, option: { value } = {} }">
        <span class="multiselect__tag bg-secondary">
          <span v-if="option[label]">{{ option[label] }}</span>
          <span v-else-if="taggable">{{ value }}</span>
          <icon v-else
              name="question-circle" variant="white" />
          <i aria-hidden="true" tabindex="1" class="multiselect__tag-icon" @click="onRemove(option)"></i>
        </span>
      </template>
      <template v-slot:beforeList>
        <li v-if="!internalSearch" class="multiselect__element">
          <div class="col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">{{ $t('Type to search') }}</div>
        </li>
      </template>
      <template v-slot:noOptions>
        <b-media class="text-secondary" md="auto" v-if="showEmpty">
          <template v-slot:aside><icon name="search" scale="1.5" class="mt-2 ml-2"></icon></template>
          <strong>{{ $t('No options') }}</strong>
          <b-form-text class="font-weight-light">{{ $t('List is empty.') }}</b-form-text>
        </b-media>
        <b-media class="text-secondary" md="auto" v-else-if="isFocus">
          <template v-slot:aside><icon name="search" scale="1.5" class="mt-2 ml-2"></icon></template>
          <strong>{{ $t('Search') }}</strong>
          <b-form-text class="font-weight-light">{{ $t('Type to search results.') }}</b-form-text>
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
import 'vue-multiselect/dist/vue-multiselect.min.css'

const components = {
  Multiselect
}

import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useOptionsPromise, useOptionsValue, useOptionsSearch } from '@/composables/useInputMultiselect'
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
    groupLabel,
    groupValues,
    groupSelect,
    options: optionsPromise,
    max,
    multiple,
    caseSensitiveSearch
  } = toRefs(metaProps)

  const options = useOptionsPromise(optionsPromise, label)

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

  const singleLabel = useOptionsValue(options, trackBy, label, groupValues, value, isFocus)

  // inspect options first item for group(ing)
  const inputGroupLabel = computed(() => {
    const { 0: { group } = {} } = options.value
    if (group)
      return 'group'
    return groupLabel.value
  })
  const inputGroupValues = computed(() => {
    const { 0: { group } = {} } = options.value
    if (group)
      return 'options'
    return groupValues.value
  })

  // vue-multiselect hacks by omitting props
  const bind = computed(() => ({
    ...((multiple.value)
      ? { max: max.value }
      : {} // `max` prop should not be used when prop `multiple=false`
    ),
    ...((groupLabel.value || groupValues.value)
      ? { 'group-select': groupSelect.value }
      : {} // `group-label` prop should not be used unless grouping is needed
    )
  }))

  // used by CSS to show vue-multiselect placeholder
  const isEmpty = computed(() => [null, undefined].includes(value.value))

  const doFocus = () => nextTick(() => context.refs.inputRef.$el.focus())
  const doBlur = () => nextTick(() => context.refs.inputRef.$el.blur())

  const onTag = newValue => onInput(newValue)

  const {
    options: searchOptions,
    onSearch
  } = useOptionsSearch(options, label, inputGroupLabel, inputGroupValues, caseSensitiveSearch.value)

  return {
    inputRef,

    // useInputMeta
    inputOptions: searchOptions,

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

    bind,
    inputGroupLabel,
    inputGroupValues,
    singleLabel,
    isEmpty,
    showEmpty: true, // always show

    onRemove: () => {},
    onTag,
    onSearch,
    isLoading: false,
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
@import '~@/styles/multiselect.scss';
</style>
