import { computed, toRefs, unref } from '@vue/composition-api'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import BaseInputSelect, { props as BaseInputSelectProps } from './BaseInputSelect'

export const props = {
  ...BaseInputSelectProps,

  multiple: {
    type: Boolean,
    default: true
  },
  closeOnSelect: {
    type: Boolean,
    default: false
  },
  internalSearch: {
    type: Boolean,
    default: true
  }
}

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)
  const {
    label,
    trackBy
  } = toRefs(metaProps)

  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const inputValueWrapper = computed(() => {
    const _value = (value.value && value.value.constructor === Array) ? value.value : [] // cast Array
    return _value.map(item => ({ [unref(label)]: item, [unref(trackBy)]: item })) // map label/trackBy
  })

  const onInputWrapper = useEventFnWrapper(onInput, _value => {
    const { [unref(trackBy)]: trackedValue } = _value
    const filteredValues = (unref(value) || []).filter(item => item !== trackedValue)
    return [ ...filteredValues, trackedValue ]
  })

  const onRemove = (option) => {
    const { [unref(trackBy)]: trackedValue } = option
    const filteredValues = (unref(value) || []).filter(item => item !== trackedValue)
    onInput(filteredValues)
  }

  const onTag = (option) => {
    const filteredValues = (unref(value) || []).filter(item => item.toLowerCase() !== option.toLowerCase())
    onInput([ ...filteredValues, option ])
  }

  return {
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,

    onRemove,
    onTag
  }
}

// @vue/component
export default {
  name: 'base-input-select-multiple',
  extends: BaseInputSelect,
  props,
  setup
}
