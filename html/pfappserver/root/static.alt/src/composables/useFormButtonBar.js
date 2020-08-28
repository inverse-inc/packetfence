import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import useEventActionKey from './useEventActionKey'
import useEvent from './useEvent'

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
  }
}

export const useFormButtonBar = (props, { emit }) => {

  const {
    isClone,
    isNew,
    isLoading,
    isDeletable
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // template refs
  const rootRef = ref(null)

  // state
  const actionKey = useEventActionKey(rootRef)

  const onClone = value => emit('clone', unref(actionKey))
  const onRemove = value => emit('remove', unref(actionKey))
  const onReset = value => emit('reset', unref(actionKey))
  const onSave = value => {
    switch (true) {
      case unref(isNew):
        emit('create', unref(actionKey))
        break
      case unref(isClone):
        emit('clone', unref(actionKey))
        break
      default:
        emit('save', unref(actionKey))
    }
  }

  return {
    rootRef,

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
