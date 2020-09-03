import { computed, toRefs, unref } from '@vue/composition-api'

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
      default: 100
    },
    step: {
      type: [String, Number],
      default: 1
    },
    color: {  // override default colors via JS
      type: String
    },
    hints: { // dots/pills in range for hints (eg: [1, [1-2], 2])
      type: Array,
      default: () => ([])
    },
    size: {
      type: String,
      validator: value => ['sm', 'md', 'lg'].includes(value)
    }
}

export const useInputRange = (props, { emit, refs }, inputRef = 'input') => {
  const {
    disabled,
    min,
    max,
    step,
    color,
    hints,
    size,
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
  const rootStyle = computed(() => ((color.value)
    ? { '--range-background-color': unref(color) }
    : {}
  ))

  const hintStyles = computed(() => unref(hints).map(hint => {
    return (hint.constructor === Array)
      ? { // range
        left: `${getPercent(hint[0])}`,
        width: `calc(${getPercent(hint[1] - hint[0])}% + var(--handle-height))`
      }
      : { // single
        left: `${getPercent(hint)}%`,
        width: 'var(--handle-height)'
      }
  }))

  const labelStyle = computed(() => {
    return (unref(value) >= ((unref(max) - unref(min)) / 2))
      ? { 'justify-content': 'flex-start' }
      : { 'justify-content': 'flex-end' }
  })

  const valueStyle = computed(() => ({
    left: `${unref(percent)}%`
  }))

  // methods
  const doFocus = () => refs[inputRef].focus()
  const doBlur = () => refs[inputRef].blur()
  const onInput = e => {
    if (disabled.value)
      return
    emit('change', e.target.value)
  }
  const onClick = e => {
    const _min = +unref(min)
    const _max = +unref(max)
    const _step = +unref(step)

    let { target, offsetX } = e
    const width = target.closest('[index]').offsetWidth

    switch (true) {
      case target.classList.contains('handle'):
console.log('@handle >>>', {offsetX})
        const _percent = unref(percent)
        offsetX += width * _percent / 100
        break
      case target.classList.contains('range'):
console.log('@range >>>', {offsetX})
        offsetX += width / 2
        break
      default:
console.log('@default >>>', {offsetX})
        //...
    }
    const slice = width / (_max - _min)
    const value = _min + Math.round(offsetX / slice)

console.log('onClick', {width, offsetX, slice, value})

    emit('change', value)
    doFocus()
  }

  return {
    // state
    rootStyle,
    hintStyles,
    labelStyle,
    valueStyle,

    // methods
    doFocus,
    doBlur,
    onInput,
    onClick
  }
}
