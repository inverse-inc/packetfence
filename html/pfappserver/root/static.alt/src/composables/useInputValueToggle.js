import { computed, toRefs, unref } from '@vue/composition-api'

export const useInputValueToggleProps = {
  label: {
    type: String
  },
  options: {
    type: Array,
    default: () => ([
      { value: 0 },
      { value: 1 }
    ])
  }
}

export const useInputValueToggle = (valueProps, props) => {

  const {
    value: rxValue,
    onChange: rxOnChange
  } = valueProps

  const {
    options
  } = toRefs(props)

  // middleware
  const txValue = computed(() => unref(options).findIndex(map => `${map.value}` === `${unref(rxValue)}`))
  const txOnChange = value => {
    const { 0: { value: defaultValue } = {} , [value]: { value: mappedValue } = {} } = unref(options)
    return rxOnChange(mappedValue || defaultValue)
  }

  // state
  const max = computed(() => unref(options).length - 1)

  const label = computed(() => {
    const { 0: { label: defaultLabel } = {} , [unref(txValue)]: { label: mappedLabel } = {} } = unref(options)
    return mappedLabel || defaultLabel
  })

  return {
    // middleware
    value: txValue,
    onChange: txOnChange,

    // state
    max,
    label
  }
}
