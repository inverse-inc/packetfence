import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useFormButtonBarProps = {
  actionKey: {
    type: Boolean
  },
  actionKeyButtonVerb: {
    type: String,
    default: i18n.t('Close')
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
    isNew,
    actionKey,
    actionKeyButtonVerb
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

  /*
           <template v-if="isNew">{{ $t('Create') }}</template>
        <template v-else-if="actionKey && isClone && canClose">{{ $t('Create & {actionKeyButtonVerb}', { actionKeyButtonVerb }) }}</template>
        <template v-else-if="isClone">{{ $t('Create') }}</template>
        <template v-else-if="actionKey">{{ $t('Save & {actionKeyButtonVerb}', { actionKeyButtonVerb }) }}</template>
        <template v-else>{{ $t('Save') }}</template>
        */

  const saveButtonLabel = computed(() => {
    switch (true) {
      case isClone.value && actionKey.value && canClose.value:
      case isNew.value && actionKey.value:
        return i18n.t('Create & {actionKeyButtonVerb}', { actionKeyButtonVerb: actionKeyButtonVerb.value })
        // break

      case isClone.value:
      case isNew.value:
        return i18n.t('Create')
        // break

      case actionKey.value:
        return i18n.t('Save & {actionKeyButtonVerb}', { actionKeyButtonVerb: actionKeyButtonVerb.value })
        // break

      default:
        return i18n.t('Save')
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

    saveButtonLabel
  }
}
