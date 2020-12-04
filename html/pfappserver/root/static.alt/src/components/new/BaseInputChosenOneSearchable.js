import { computed, toRefs, unref } from '@vue/composition-api'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInput } from '@/composables/useInput'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import { useOptionsPromise, useOptionsValue, useSingleValueLookupOptions } from '@/composables/useInputMultiselect'
import BaseInputChosen, { props as BaseInputChosenProps } from './BaseInputChosen'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputChosenProps,

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
    onSearch,
    showEmpty
  } = useSingleValueLookupOptions(value, onInput, lookup, options, optionsLimit, trackBy, label)

  const singleLabel = useOptionsValue(inputOptions, trackBy, label, value, isFocus, isLoading)

  const inputValueWrapper = computed(() => {
    const _value = unref(value)
    const _options = unref(inputOptions)
    const optionsIndex = _options.findIndex(option => option[unref(trackBy)] === _value)
    if (optionsIndex > -1) {
      return _options[optionsIndex]
    }
    else {
      return { [unref(label)]: _value, [unref(trackBy)]: _value }
    }
  })

  const inputPlaceholder = useOptionsValue(inputOptions, trackBy, label, placeholder, isFocus, isLoading)

  const onInputWrapper = useEventFnWrapper(onInput, value => {
    const { [unref(trackBy)]: trackedValue } = value
    return trackedValue
  })

  return {
    // useInput
    isFocus,
    onFocus,
    onBlur,

    // useSingleValueLookupOptions
    inputOptions,
    isLoading,
    onSearch,
    showEmpty,

    singleLabel,
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,
    inputPlaceholder
  }
}

// @vue/component
export default {
  name: 'base-input-chosen-one-searchable',
  extends: BaseInputChosen,
  props,
  setup
}
