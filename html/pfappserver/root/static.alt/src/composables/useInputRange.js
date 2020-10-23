import { computed, nextTick, toRefs, unref } from '@vue/composition-api'

export const useInputRangeProps = {
    value: {
      default: null
    },
    disabled: {
      type: Boolean
    },
    min: {
      type: [String, Number],
      default: 0
    },
    max: {
      type: [String, Number],
      default: 1
    },
    color: {  // override default colors via JS
      type: String
    },
    hints: { // dots/pills in range for hints (eg: [1, [1-2], 2])
      type: Array,
      default: () => ([])
    }
}

export const useInputRange = (props, { emit, refs }, inputRef = 'input') => {
  const {
    disabled,
    min,
    max,
    color,
    hints,
    value
  } = toRefs(props)

  // helpers
  const getPercent = value => {
    value = +value
    const _min = +unref(min)
    const _max = +unref(max)
    if (value >= _max) return 100
    if (value <= _min) return 0
    return (100 / (_max - _min)) * value - (100 / (_max - _min)) * _min
  }

  const percent = computed(() => getPercent(unref(value)))

  // state
  const defaultValue = computed(() => unref(min))

  const rootStyle = computed(() => ({
    '--range-length': max.value - min.value + 1,
    ...((color.value)
      ? { '--range-background-color': unref(color) }
      : {}
    )
  }))

  const hintStyles = computed(() => unref(hints).map(hint => ((hint.constructor === Array)
    ? { // range
      left: `${getPercent(hint[0])}%`,
      width: `calc(${getPercent(hint[1] - hint[0])}% + var(--handle-height))`
    }
    : { // single
      left: `${getPercent(hint)}%`,
      width: 'var(--handle-height)'
    }
  )))

  const labelStyle = computed(() => ((unref(value) >= ((unref(max) - unref(min)) / 2))
      ? { 'justify-content': 'flex-start' }
      : { 'justify-content': 'flex-end' }
  ))

  const valueStyle = computed(() => ({
    left: `${unref(percent)}%`
  }))

  // methods
  const doFocus = () => nextTick(() => refs[inputRef].focus())
  const doBlur = () => nextTick(() => refs[inputRef].blur())
  const onInput = e => {
    if (disabled.value)
      return
    emit('input', e.target.value)
  }

  return {
    // state
    defaultValue,
    rootStyle,
    hintStyles,
    labelStyle,
    valueStyle,

    // methods
    doFocus,
    doBlur,
    onInput
  }
}
