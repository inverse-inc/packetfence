import { computed, toRefs } from '@vue/composition-api'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import { useOptionsPromise } from '@/composables/useInputMultiselect'
import BaseInputChosen, { props as BaseInputChosenProps } from './BaseInputChosen'

export const props = {
  ...BaseInputChosenProps,

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
    trackBy,
    options: optionsPromise
  } = toRefs(metaProps)

  const options = useOptionsPromise(optionsPromise, label)

  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const inputValueWrapper = computed(() => {
    const _value = (value.value && value.value.constructor === Array) ? value.value : [] // cast Array
    return _value.map(item => ({ [label.value]: item, [trackBy.value]: item })) // map label/trackBy
  })

  const onInputWrapper = useEventFnWrapper(onInput, _value => {
    const _values = (_value.constructor === Array)
      ? _value // is group(ed)
      : [_value] // is singular
    let valueCopy = (value.value || [])
    for (_value of _values) {
      const { [trackBy.value]: trackedValue } = _value
      valueCopy = [ ...valueCopy.filter(item => item !== trackedValue), trackedValue ]
    }
    return valueCopy
  })

  const onRemove = (option) => {
    const { [trackBy.value]: trackedValue } = option
    const filteredValues = (value.value || []).filter(item => item !== trackedValue)
    onInput(filteredValues)
  }

  const onTag = (option) => {
    const filteredValues = (value.value || []).filter(item => item.toLowerCase() !== option.toLowerCase())
    onInput([ ...filteredValues, option ])
  }

  const canSelectAll = computed(() => options.value.length > 0)
  const onSelectAll = () => {
    onInput(options.value.map(option => {
      const { [trackBy.value]: trackedValue } = option
      return trackedValue
    }))
  }
  const canSelectNone = computed(() => !!(value.value && value.value.length))
  const onSelectNone = () => onInput([])

  return {
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,

    onRemove,
    onTag,

    canSelectAll,
    canSelectNone,
    onSelectAll,
    onSelectNone
  }
}

// @vue/component
export default {
  name: 'base-input-chosen-multiple',
  extends: BaseInputChosen,
  props,
  setup
}
