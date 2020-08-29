import { ref, toRefs, unref } from '@vue/composition-api'
import useEventActionKey from './useEventActionKey'

export const useFormButtonBarProps = {
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
  formRef: {
    type: HTMLFormElement
  }
}

export const useFormButtonBar = (props, { emit }) => {

  const {
    isClone,
    isNew,
    isLoading,
    isDeletable,
    formRef
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // state
  const actionKey = useEventActionKey(formRef)

  const onClone = value => emit('clone', unref(actionKey), value)
  const onRemove = value => emit('remove', unref(actionKey), value)
  const onReset = value => emit('reset', unref(actionKey), value)
  const onSave = value => {
    switch (true) {
      case unref(isNew):
        emit('create', unref(actionKey), value)
        break
      case unref(isClone):
        emit('clone', unref(actionKey), value)
        break
      default:
        emit('save', unref(actionKey), value)
    }
  }

  return {
    isClone,
    isNew,
    isLoading,
    isDeletable,
    actionKey,

    onClone,
    onRemove,
    onReset,
    onSave
  }
}
