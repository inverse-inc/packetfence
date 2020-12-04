import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import { useOptionsPromise, useOptionsValue } from '@/composables/useInputMultiselect'
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
    options: optionsPromise,
    placeholder
  } = toRefs(metaProps)

  const options = useOptionsPromise(optionsPromise)

  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const inputValueWrapper = computed(() => {
    const _value = unref(value)
    const _options = unref(options)
    const optionsIndex = _options.findIndex(option => option[trackBy.value] === _value)
    if (optionsIndex > -1)
      return _options[optionsIndex]
    else
      return { [label.value]: _value, [trackBy.value]: _value }
  })

  const inputPlaceholder = useOptionsValue(options, trackBy, label, placeholder)

  const onInputWrapper = useEventFnWrapper(onInput, value => {
    const { [trackBy.value]: trackedValue } = value
    return trackedValue
  })

  return {
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,
    inputPlaceholder
  }
}

// @vue/component
export default {
  name: 'base-form-group-chosen-one',
  extends: BaseFormGroupChosen,
  props,
  setup
}
