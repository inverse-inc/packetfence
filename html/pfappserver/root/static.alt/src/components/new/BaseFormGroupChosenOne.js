import { computed, toRefs, unref } from '@vue/composition-api'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import BaseFormGroupChosen, { props as BaseFormGroupChosenProps } from './BaseFormGroupChosen'

export const props = {
  ...BaseFormGroupChosenProps,

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
    options
  } = toRefs(metaProps)

  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const inputValueWrapper = computed(() => {
    const _value = unref(value)
    const _options = unref(options)
    const optionsIndex = _options.findIndex(option => option[trackBy] === _value)
    if (optionsIndex > -1) {
      return _options[optionsIndex]
    }
    else {
      return { [unref(label)]: _value, [unref(trackBy)]: _value }
    }
  })

  const onInputWrapper = useEventFnWrapper(onInput, value => {
    const { [unref(trackBy)]: trackedValue } = value
    return trackedValue
  })

  return {
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,
  }
}

// @vue/component
export default {
  name: 'base-form-group-chosen-one',
  extends: BaseFormGroupChosen,
  props,
  setup
}
