import { computed, toRefs, unref } from '@vue/composition-api'

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

export const useInputValueToggle = (valueProps, props) => {

  const {
    value: rxValue,
    onInput: rxOnInput
  } = valueProps

  const {
    options
  } = toRefs(props)

  // middleware
  const txValue = computed(() => unref(options).findIndex(map => {
    if (!map.value && !rxValue.value)
      return true // compare False(y) w/ [null|undefined]
    else
      return `${map.value}` === `${rxValue.value}` // compare String(s)
  }))
  const txOnInput = value => {
    const { 0: { value: defaultValue } = {} , [value]: { value: mappedValue } = {} } = unref(options)
    return rxOnInput((mappedValue !== undefined) ? mappedValue : defaultValue)
  }

  // state
  const max = computed(() => unref(options).length - 1)

  const label = computed(() => {
    const { 0: { label: defaultLabel } = {} , [unref(txValue)]: { label: mappedLabel } = {} } = unref(options)
    return mappedLabel || defaultLabel
  })

  const color = computed(() => {
    const { 0: { color: defaultColor } = {} , [unref(txValue)]: { color: mappedColor } = {} } = unref(options)
    return mappedColor || defaultColor
  })

  const icon = computed(() => {
    const { 0: { icon: defaultIcon } = {} , [unref(txValue)]: { icon: mappedIcon } = {} } = unref(options)
    return mappedIcon || defaultIcon
  })

 const tooltip = computed(() => {
    const { 0: { tooltip: defaultTooltip } = {} , [unref(txValue)]: { tooltip: mappedTooltip } = {} } = unref(options)
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
