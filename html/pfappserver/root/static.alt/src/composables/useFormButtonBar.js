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

export const useFormButtonBar = (props, { emit }) => {

  const {
    isClone,
    isNew
  } = toRefs(props)

  const isCloneable = computed(() => isClone.value === false || isNew.value === false)

  const onClone = value => emit('clone', value)
  const onRemove = value => emit('remove', value)
  const onReset = value => emit('reset', value)
  const onSave = value => emit('save', value)

  return {
    isCloneable,

    onClone,
    onRemove,
    onReset,
    onSave
  }
}
