import { computed, toRefs } from '@vue/composition-api'

export const useInputValueToggleProps = {
  label: {
    type: String
  },
  options: {
    type: Array,
    default: () => ([
      { value: 0 },
      { value: 1, color: 'var(--primary)' }
    ])
  },
  hints: {
    type: Array
  }
}

export const useInputValueToggle = (valueProps, props, context) => {

  const {
    value: rxValue,
    onInput: rxOnInput
  } = valueProps

  const {
    options
  } = toRefs(props)

  // middleware
  const txValue = computed(() => options.value.findIndex(map => {
    if (!map.value && !rxValue.value)
      return true // compare False(y) w/ [null|undefined]
    else
      return `${map.value}` === `${rxValue.value}` // compare String(s)
  }))
  const txOnInput = value => {
    const {
      0: { value: defaultValue } = {}, // 0th option is default
      [value]: { value: mappedValue } = {}, // map value (N) w/ Nth option
      [value]: { promise: mappedPromise } = {} // map promise
    } = options.value
    const rxValue = (mappedValue !== undefined) ? mappedValue : defaultValue
    if (mappedPromise) // handle Promise
      return mappedPromise(rxValue, props, context)
    else // otherwise emit
      return rxOnInput(rxValue)
  }

  // state
  const max = computed(() => `${options.value.length - 1}`)

  const label = computed(() => {
    const { 0: { label: defaultLabel } = {} , [txValue.value]: { label: mappedLabel } = {} } = options.value
    return mappedLabel || defaultLabel
  })

  const color = computed(() => {
    const { 0: { color: defaultColor } = {} , [txValue.value]: { color: mappedColor } = {} } = options.value
    return mappedColor || defaultColor
  })

  const icon = computed(() => {
    const { 0: { icon: defaultIcon } = {} , [txValue.value]: { icon: mappedIcon } = {} } = options.value
    return mappedIcon || defaultIcon
  })

 const tooltip = computed(() => {
    const { 0: { tooltip: defaultTooltip } = {} , [txValue.value]: { tooltip: mappedTooltip } = {} } = options.value
    return mappedTooltip || defaultTooltip
  })

  return {
    // middleware
    value: txValue,
    onInput: txOnInput,

    // state
    max,
    label,
    color,
    icon,
    tooltip
  }
}
