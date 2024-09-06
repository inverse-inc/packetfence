<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :content-cols="contentCols"
    :content-cols-sm="contentColsSm"
    :content-cols-md="contentColsMd"
    :content-cols-lg="contentColsLg"
    :content-cols-xl="contentColsXl"
    :label="columnLabel"
    :label-class="labelClass"
    :label-cols="labelCols"
    :label-cols-sm="labelColsSm"
    :label-cols-md="labelColsMd"
    :label-cols-lg="labelColsLg"
    :label-cols-xl="labelColsXl"
    :state="inputState"
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
          'is-empty': isEmpty,
          'size-sm': size === 'sm',
          'size-md': size === 'md',
          'size-lg': size === 'lg'
        }"
        :data-namespace="namespace"

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
        @search-change="onSearch"

        v-bind="bind"
      >
        <template v-slot:singleLabel>
          {{ singleLabel }}
        </template>
        <template v-slot:tag="{ option, option: { value } = {} }">
          <span class="multiselect__tag bg-secondary">
            <span v-if="multipleLabels[value]">{{ multipleLabels[value] }}</span>
            <span v-else-if="taggable">{{ value }}</span>
            <icon v-else
              name="question-circle" variant="white" />
            <i aria-hidden="true" tabindex="1" class="multiselect__tag-icon" @click="onRemove(option)"></i>
          </span>
        </template>
        <template v-slot:beforeList>
          <li class="multiselect__element" v-if="!internalSearch || multiple">
            <div class="text-right" v-if="multiple && internalSearch">
              <b-button v-if="canSelectAll"
                variant="link" size="sm" @click="onSelectAll">{{ $t('Select All') }}</b-button>
              <b-button v-if="canSelectNone"
                variant="link" size="sm" @click="onSelectNone">{{ $t('Select None') }}</b-button>
            </div>
            <div v-if="!internalSearch"
              class="mr-auto col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">{{ $t('Type to search') }}</div>
          </li>
        </template>
        <template v-slot:noOptions>
          <b-media class="text-secondary" md="auto" v-if="showEmpty">
            <template v-slot:aside><icon name="search" scale="1.5" class="mt-2 ml-2"></icon></template>
            <strong>{{ $t('No options') }}</strong>
            <b-form-text v-if="taggable"
              class="font-weight-light">{{ $t('Enter a new value.') }}</b-form-text>
            <b-form-text v-else
              class="font-weight-light">{{ $t('List is empty.') }}</b-form-text>
          </b-media>
          <b-media class="text-secondary" md="auto" v-else>
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
      <template v-slot:prepend v-if="$slots.prepend || (inputPlaceholder && isEmpty)">
        <slot  v-if="$slots.prepend" name="prepend"></slot>
        <b-button v-if="isDefault && isEmpty"
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
          v-b-tooltip.hover.left.d300 :title="$t('A default value is provided if this field is not defined.')"
        >
          <icon ref="icon-default"
            name="stamp" scale="0.75"
          />
        </b-button>
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
    <template v-slot:description v-if="inputText || inputApiFeedback">
      <div v-if="inputApiFeedback" v-html="inputApiFeedback" class="text-warning"/>
      <div v-if="inputText" v-html="inputText"/>
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

import i18n from '@/utils/locale'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, toRefs } from '@vue/composition-api'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useOptionsPromise, useOptionsValue } from '@/composables/useInputMultiselect'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useInputMultiselectProps, useOptionsSearch } from '@/composables/useInputMultiselect'

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
  placeholder: {
    type: String,
    default: i18n.t('Select option')
  }
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
    isDefault,
    isFocus,
    isLocked,
    onFocus,
    onBlur
  } = useInput(metaProps, context)

  const {
    value,
    onInput,
    isEmpty
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback,
    apiFeedback
  } = useInputValidator(metaProps, value)

  const inputGroupLabel = computed(() => {
    if (groupLabel.value)
      return groupLabel.value
    // inspect options first item for group(ing)
    const { 0: { group } = {} } = options.value
    if (group)
      return 'group'
    return undefined
  })
  const inputGroupValues = computed(() => {
    if (groupValues.value)
      return groupValues.value
    // inspect options first item for group(ing)
    const { 0: { group } = {} } = options.value
    if (group)
      return 'options'
    return undefined
  })

  const singleLabel = useOptionsValue(options, trackBy, label, groupValues, value, isFocus)

  const multipleLabels = computed(() => {
    let _options = options.value
    if (inputGroupLabel.value) { // grouped options
      _options = options.value.reduce((options, group) => { // flatten
        const { [inputGroupValues.value]: groupValues } = group
        return [ ...options, ...groupValues ]
      }, [])
    }
    return _options.reduce((labels, option) => {
      const { text, value } = option
      return { ...labels, [value]: text }
    }, {})
  })

  // supress warning:
  //  [Vue-Multiselect warn]: Max prop should not be used when prop Multiple equals false.
  const bind = computed(() => {
    return (multiple.value)
      ? { max: max.value }
      : {}
  })

  // clear single value
  const onRemove = () => onInput(null)

  const doFocus = () => nextTick(() => context.refs.inputRef.$el.focus())
  const doBlur = () => nextTick(() => context.refs.inputRef.$el.blur())

  const canSelectAll = computed(() => options.value.length > 0)
  const onSelectAll = () => {
    let _options = options.value
    if (inputGroupLabel.value) { // grouped options
      _options = options.value.reduce((options, group) => { // flatten
        const { [inputGroupValues.value]: groupValues } = group
        return [ ...options, ...groupValues ]
      }, [])
    }
    onInput(_options.map(option => {
      const { [trackBy.value]: trackedValue } = option
      return trackedValue
    }))
  }
  const canSelectNone = computed(() => !!value.value)
  const onSelectNone = () => onRemove()

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
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
    isDefault,
    isFocus,
    isLocked,
    isReadonly: readonly,
    canSelectAll,
    canSelectNone,
    onFocus,
    onBlur,
    onSelectAll,
    onSelectNone,

    // useInputValue
    inputValue: value,
    isEmpty,
    onInput,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,
    inputApiFeedback: apiFeedback,

    bind,
    inputGroupLabel,
    inputGroupValues,
    singleLabel,
    multipleLabels,
    showEmpty: true, // always show

    onRemove,
    onTag: () => {},
    onSearch,
    isLoading: false,
    doFocus,
    doBlur,
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
