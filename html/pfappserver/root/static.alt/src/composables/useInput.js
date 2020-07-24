import { ref, toRefs, unref, computed } from '@vue/composition-api'

export const useInputProps = {
  value: {
    default: null
  },
  disabled: {
    type: Boolean,
    default: false
  },
  placeholder: {
    type: String
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
  type: {
    type: String,
    default: 'text'
  }
}

export const useInput = (props, { emit, parent, refs }, inputRef = 'input') => {

  const {
    value,
    disabled,
    placeholder,
    readonly,
    tabIndex,
    text,
    type
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // state
  const isFocus = ref(false)
  const isLocked = computed(() => unref(disabled) || unref(readonly))

  // methods
  const doFocus = () => refs[inputRef].$el.focus()
  const doBlur = () => refs[inputRef].$el.blur()
  const doSelect = () => refs[inputRef].$el.select()

  // events
  const onInput = value => emit('input', value)
  const onChange = value => emit('change', value)
  const onFocus = event => {
    isFocus.value = true
    emit('focus', event)
  }
  const onBlur = event => {
    isFocus.value = false
    emit('blur', event)
  }

  return {
    // props
    value,
    placeholder,
    readonly,
    tabIndex,
    text,
    type,

    // state
    isFocus,
    isLocked,

    // methods
    doFocus,
    doBlur,
    doSelect,

    //events
    onInput,
    onChange,
    onFocus,
    onBlur
  }
}
