import i18n from '@/utils/locale'
import { computed, toRefs } from '@vue/composition-api'
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
  },
  placeholder: {
    type: String,
    default: i18n.t('Select option(s)')
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
    return (value.value || []).map(item => ({ [label.value]: item, [trackBy.value]: item }))
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

  const onRemove = option => {
    const { [trackBy.value]: trackedValue } = option
    const filteredValues = (value.value || []).filter(item => item !== trackedValue)
    onInput(filteredValues)
  }

  const onTag = newValue => {
    if (value.value)
      onInput([...value.value, newValue])
    else
      onInput([newValue])
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
  name: 'base-form-group-chosen-multiple',
  extends: BaseFormGroupChosen,
  props,
  setup
}
