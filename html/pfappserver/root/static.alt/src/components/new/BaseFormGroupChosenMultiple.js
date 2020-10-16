import { computed, toRefs, unref } from '@vue/composition-api'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import BaseFormGroupChosen, { props as BaseFormGroupChosenProps } from './BaseFormGroupChosen'

export const props = {
  ...BaseFormGroupChosenProps,

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
    return (unref(value) || []).map(item => ({ [unref(label)]: item, [unref(trackBy)]: item }))
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

  return {
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,

    onRemove
  }
}

// @vue/component
export default {
  name: 'base-form-group-chosen-multiple',
  extends: BaseFormGroupChosen,
  props,
  setup
}
