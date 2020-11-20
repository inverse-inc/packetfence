import { computed, toRefs } from '@vue/composition-api'

export const useFormButtonBarProps = {
  actionKey: {
    type: Boolean
  },
  isClone: {
    type: Boolean,
    default: undefined // allow explicit `false`
  },
  isNew: {
    type: Boolean,
    default: undefined // allow explicit `false`
  },
  isLoading: {
    type: Boolean
  },
  isDeletable: {
    type: Boolean
  },
  isValid: {
    type: Boolean
  },
  formRef: {
    type: HTMLFormElement
  }
}

export const useFormButtonBar = (props, context) => {

  const {
    isClone,
    isNew
  } = toRefs(props)

  const { emit, listeners } = context

  const isCloneable = computed(() => {
    return isClone.value === false && isNew.value === false && 'clone' in listeners
  })

  const isCloseable = computed(() => {
    return 'close' in listeners
  })

  const onClone = value => emit('clone', value)
  const onClose = value => emit('close', value)
  const onRemove = value => emit('remove', value)
  const onReset = value => emit('reset', value)
  const onSave = value => emit('save', value)

  return {
    isCloneable,
    isCloseable,

    onClone,
    onClose,
    onRemove,
    onReset,
    onSave
  }
}
