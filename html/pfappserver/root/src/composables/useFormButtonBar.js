import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

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
  },
  labelActionKey: {
    type: String,
    default: 'Close' // i18n.defer
  },
  labelCreate: {
    type: String,
    default: 'Create' // i18n.defer
  },
  labelSave: {
    type: String,
    default: 'Save' // i18n.defer
  },
  confirmSave: {
    type: Boolean
  }
}

export const useFormButtonBar = (props, context) => {

  const {
    isClone,
    isCloneable,
    isDeletable,
    isSaveable,
    isNew,
    actionKey,
    labelActionKey,
    labelCreate,
    labelSave,
    confirmSave,
  } = toRefs(props)

  const { emit, listeners } = context

  const canClone = computed(() => {
    return isCloneable.value && !isClone.value && !isNew.value && 'clone' in listeners
  })

  const canClose = computed(() => {
    return 'close' in listeners
  })

  const canDelete = computed(() => {
    return isDeletable.value && !isClone.value && !isNew.value && 'remove' in listeners
  })

  const canSave = computed(() => {
    return isSaveable.value && 'save' in listeners
  })

  const onClone = value => emit('clone', value)
  const onClose = value => emit('close', value)
  const onRemove = value => emit('remove', value)
  const onReset = value => emit('reset', value)
  const onSave = value => emit('save', value)

  const saveButtonLabel = computed(() => {
    switch (true) {
      case isClone.value && actionKey.value && canClose.value:
      case isNew.value && actionKey.value:
        return i18n.t(`${labelCreate.value} & ${labelActionKey.value}`)
        // break

      case isClone.value:
      case isNew.value:
        return i18n.t(labelCreate.value)
        // break

      case actionKey.value:
        return i18n.t(`${labelSave.value} & ${labelActionKey.value}`)
        // break

      default:
        return i18n.t(labelSave.value)
    }
  })

  return {
    canClone,
    canClose,
    canDelete,
    canSave,

    onClone,
    onClose,
    onRemove,
    onReset,
    onSave,

    saveButtonLabel,
    confirmSave
  }
}
