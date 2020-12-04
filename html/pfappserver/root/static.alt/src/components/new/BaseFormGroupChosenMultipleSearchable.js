import { computed, toRefs } from '@vue/composition-api'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInput } from '@/composables/useInput'
import { useInputMeta } from '@/composables/useMeta'
import { useOptionsPromise, useOptionsValue, useMultipleValueLookupOptions } from '@/composables/useInputMultiselect'
import { useInputValue } from '@/composables/useInputValue'
import BaseFormGroupChosenMultiple, { props as BaseFormGroupChosenMultipleProps } from './BaseFormGroupChosenMultiple'

export const props = {
  ...BaseFormGroupChosenMultipleProps,

  // preserve search string when option is chosen
  clearOnSelect: {
    type: Boolean,
    default: false
  },
  // use async search, not internal
  internalSearch: {
    type: Boolean,
    default: false
  },
  // meta allowed_lookup { field_name, search_path, value_name }
  lookup: {
    type: Object,
    default: () => ({})
  }
}

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)
  const {
    label,
    lookup,
    trackBy,
    options: optionsPromise,
    optionsLimit
  } = toRefs(metaProps)

  const options = useOptionsPromise(optionsPromise)

  const {
    placeholder,
    isFocus,
    onFocus,
    onBlur
  } = useInput(metaProps, context)

  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const {
    options: inputOptions,
    isLoading,
    onRemove,
    onSearch,
    showEmpty
  } = useMultipleValueLookupOptions(value, onInput, lookup, options, optionsLimit, trackBy, label)

  const multipleLabels = computed(() => inputOptions.value.reduce((labels, option) => {
    const { text, value } = option
    return { ...labels, [value]: text }
  }, {}))

  const inputValueWrapper = computed(() => {
    return (value.value || []).map(item => {
      const optionsIndex = inputOptions.value.findIndex(option => option[trackBy.value] === item)
      if (optionsIndex > -1)
        return inputOptions.value[optionsIndex]
      return ({ [label.value]: item, [trackBy.value]: item })
    })
  })

  const onInputWrapper = useEventFnWrapper(onInput, _value => {
    const { [trackBy.value]: trackedValue } = _value
    const filteredValues = (value.value || []).filter(item => item !== trackedValue)
    return [ ...filteredValues, trackedValue ]
  })

  const inputPlaceholder = useOptionsValue(options, trackBy, label, placeholder, isFocus, isLoading)

  return {
    // useInput
    isFocus,
    onFocus,
    onBlur,

    // useSingleValueLookupOptions
    inputOptions,
    isLoading,
    onRemove,
    onSearch,
    showEmpty,

    multipleLabels,
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,
    inputPlaceholder
  }
}

// @vue/component
export default {
  name: 'base-form-group-chosen-multiple-searchable',
  extends: BaseFormGroupChosenMultiple,
  props,
  setup
}
