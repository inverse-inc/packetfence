import { inject, nextTick, ref, toRefs, unref, computed } from '@vue/composition-api'

export const useInputProps = {
  disabled: {
    type: Boolean,
    default: false
  },
  placeholder: {
    type: [String, Number, Array]
  },
  readonly: {
    type: Boolean,
    default: false
  },
  tabIndex: {
    type: [String, Number],
    default: 0
  },
  text: {
    type: String
  },
  textFn: {
    type: Function
  },
  type: {
    type: String,
    default: 'text'
  },
  min: { // <input type="range" min="..."
    type: String
  },
  max: { // <input type="range" max="..."
    type: String
  }
}

export const useInput = (props, { emit, refs }, inputRef = 'input') => {

  const {
    disabled,
    placeholder,
    readonly,
    tabIndex,
    text,
    type
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // props
  const localPlaceholder = computed(() =>
    (unref(placeholder) && unref(placeholder).constructor === Array)
      ? unref(placeholder).join(', ') // join Array to String
      : (unref(placeholder))
        ? `${unref(placeholder)}` // cast String
        : '' // empty String
  )

  // state
  const isFocus = ref(false)
  const isLoading = inject('isLoading', ref(false))
  const isReadonly = inject('isReadonly', ref(false))
  const isLocked = computed(() => unref(isReadonly) || unref(isLoading) || unref(disabled) || unref(readonly))

  const localReadonly = computed(() => {
    return isReadonly.value || readonly.value || false
  })

  // methods
  const doFocus = () => nextTick(() => refs[inputRef].$el.focus())
  const doBlur = () => nextTick(() => refs[inputRef].$el.blur())
  const doSelect = () => nextTick(() => refs[inputRef].$el.select())

  // events
  const onFocus = event => {
    isFocus.value = true
    emit('focus', event)
  }
  let onBlurTimeout
  const onBlur = event => {
    if (onBlurTimeout)
      clearTimeout(onBlurTimeout)
    isFocus.value = false
    onBlurTimeout = setTimeout(() => {
      emit('blur', event)
    }, 300)
  }

  const isDefault = computed(() => localPlaceholder.value && !/^(select|sélect)/i.test(localPlaceholder.value))

  return {
    // props
    placeholder: localPlaceholder,
    readonly: localReadonly,
    tabIndex,
    text,
    type,

    // state
    isDefault,
    isFocus,
    isLocked,

    // methods
    doFocus,
    doBlur,
    doSelect,

    //events
    onFocus,
    onBlur
  }
}
