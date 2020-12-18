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
  isCloneable: {
    type: Boolean
  },
  isDeletable: {
    type: Boolean
  },
  isSaveable: {
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
    isCloneable,
    isDeletable,
    isSaveable,
    isNew
  } = toRefs(props)

  const { emit, listeners } = context

  const canClone = computed(() => {
    return isCloneable.value && isClone.value === false && isNew.value === false && 'clone' in listeners
  })

  const canClose = computed(() => {
    return 'close' in listeners
  })

  const canDelete = computed(() => {
    return isDeletable.value && isClone.value === false && isNew.value === false && 'remove' in listeners
  })

  const canReset = true /*computed(() => {
    return isNew.value === false
  })*/

  const canSave = computed(() => {
    return isSaveable.value && 'save' in listeners
  })

  const onClone = value => emit('clone', value)
  const onClose = value => emit('close', value)
  const onRemove = value => emit('remove', value)
  const onReset = value => emit('reset', value)
  const onSave = value => emit('save', value)

  return {
    canClone,
    canClose,
    canDelete,
    canReset,
    canSave,

    onClone,
    onClose,
    onRemove,
    onReset,
    onSave
  }
}
