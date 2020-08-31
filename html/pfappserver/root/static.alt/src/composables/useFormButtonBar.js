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

  const {
    isClone,
    isNew
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  const onClone = value => emit('clone', value)
  const onRemove = value => emit('remove', value)
  const onReset = value => emit('reset', value)
  const onSave = value => {
    switch (true) {
      case unref(isNew):
        emit('create', value)
        break
      case unref(isClone):
      default:
        emit('save', value)
        break
    }
  }

  return {
    onClone,
    onRemove,
    onReset,
    onSave
  }
}
