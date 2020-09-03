import { toRefs, unref } from '@vue/composition-api'

export const useFormButtonBarProps = {
  actionKey: {
    type: Boolean
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
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

export const useFormButtonBar = (props, { emit }) => {

  const onClone = value => emit('clone', value)
  const onRemove = value => emit('remove', value)
  const onReset = value => emit('reset', value)
  const onSave = value => emit('save', value)

  return {
    onClone,
    onRemove,
    onReset,
    onSave
  }
}
