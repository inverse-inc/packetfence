import { nextTick, ref, unref, watch } from '@vue/composition-api'
import uuidv4 from 'uuid/v4'

export const useArrayDraggableProps = {
  childComponent: {
    type: Object
  },
  defaultItem: {
    type: Object,
    default: () => ({})
  },
  onAdd: {
    type: Function,
    default: (context, index, newComponent) => {
      const { emit } = context
      emit('add', index, newComponent)
    }
  },
  onCopy: {
    type: Function,
    default: (context, fromIndex, toIndex, fromComponent, toComponent) => {
      const { emit } = context
      emit('copy', fromIndex, toIndex, fromComponent, toComponent)
    }
  },
  onMove: {
    type: Function,
    default: (context, fromIndex, toIndex, fromComponent, toComponent) => {
      const { emit } = context
      emit('move', fromIndex, toIndex, fromComponent, toComponent)
    }
  },
  onRemove: {
    type: Function,
    default: (context, index, oldComponent) => {
      const { emit } = context
      emit('remove', index, oldComponent)
    }
  },
  onTruncate: {
    type: Function,
    default: (context) => {
      const { emit } = context
      emit('truncate')
    }
  }
}

export const useArrayDraggable = (props, context, value, onChange) => {

  const {
    onAdd,
    onCopy,
    onMove,
    onRemove,
    onTruncate
  } = props

  const draggableRef = ref(null)
  const draggableKeys = ref([...Array((unref(value) || []).length).keys()].map(() => uuidv4()))
  let isLoading = false

  watch(
    () => (unref(value) || []).length,
    (lengthAfter, lengthBefore) => {
      if (isLoading) return // internal mutation
      if ((!lengthBefore || !lengthAfter) && ~~lengthBefore !== ~~lengthAfter) { // external mutation
        draggableKeys.value = [...Array(lengthAfter).keys()].map(() => uuidv4())
      }
    },
    { immediate: true }
  )

  const add = (index, newValue) => {
    const _newValue = JSON.parse(JSON.stringify(newValue))
    isLoading = true
    return new Promise(resolve => {
      const _value = unref(value) || []
      onChange([..._value.slice(0, index), _newValue, ..._value.slice(index)])

      const _keys = unref(draggableKeys)
      const newKey = uuidv4()
      draggableKeys.value = [..._keys.slice(0, index), newKey, ..._keys.slice(index)]

      nextTick(() => {
        isLoading = false
        const { refs: { [newKey]: { 0: newComponent = {} } = {} } = {} } = context
        unref(onAdd)(context, index, newComponent)
        resolve()
      })
    })
  }

  const copy = (fromIndex, toIndex) => {
    isLoading = true
    return new Promise(resolve => {
      const _value = unref(value) || []
      const newValue = JSON.parse(JSON.stringify(_value[fromIndex])) // dereferenced copy
      onChange([..._value.slice(0, toIndex), newValue, ..._value.slice(toIndex)])

      const _keys = unref(draggableKeys)
      const { refs: { [_keys[fromIndex]]: { 0: fromComponent = {} } = {} } = {} } = context
      const newKey = uuidv4()
      draggableKeys.value = [..._keys.slice(0, toIndex), newKey, ..._keys.slice(toIndex)]

      nextTick(() => {
        isLoading = false
        const { refs: { [newKey]: { 0: toComponent = {} } = {} } = {} } = context
        unref(onCopy)(context, fromIndex, toIndex, fromComponent, toComponent)
        resolve()
      })
    })
  }

  const move = (fromIndex, toIndex) => {
    isLoading = true
    return new Promise(resolve => {
      const _value = unref(value) || []
      const newValue = JSON.parse(JSON.stringify(_value)) // dereferenced copy
      if (toIndex >= newValue.length) {
        var k = toIndex - newValue.length + 1
        while (k--) {
          newValue.push(undefined)
          draggableKeys.value.push(undefined)
        }
      }
      newValue.splice(toIndex, 0, newValue.splice(fromIndex, 1)[0])
      onChange(newValue)

      const _keys = unref(draggableKeys)
      const { refs: { [_keys[fromIndex]]: { 0: fromComponent = {} } = {} } = {} } = context
      draggableKeys.value.splice(toIndex, 0, draggableKeys.value.splice(fromIndex, 1)[0])

      nextTick(() => {
        isLoading = false
        const { refs: { [_keys[toIndex]]: { 0: toComponent = {} } = {} } = {}  } = context
        unref(onMove)(context, fromIndex, toIndex, fromComponent, toComponent)
        resolve()
      })
    })
  }

  const remove = (index) => {
    isLoading = true
    return new Promise(resolve => {
      const _value = unref(value) || []
      onChange([..._value.slice(0, index), ..._value.slice(index + 1, _value.length)])

      const _keys = unref(draggableKeys)
      const { refs: { [_keys[index]]: { 0: oldComponent = {} } = {} } = {} } = context
      draggableKeys.value = [..._keys.slice(0, index), ..._keys.slice(index + 1, _keys.length)]

      nextTick(() => {
        isLoading = false
        unref(onRemove)(context, index, oldComponent)
        resolve()
      })
    })
  }

  const truncate = () => {
    isLoading = true
    return new Promise(resolve => {
      onChange([])

      draggableKeys.value = []

      nextTick(() => {
        isLoading = false
        onTruncate(context)
        resolve()
      })
    })
  }

  const draggableListeners = {
    end: (e) => {
      const { newIndex, oldIndex } = e
      move(oldIndex, newIndex)
    }
  }

  return {
    // template refs
    draggableRef,

    // props
    draggableKeys,

    // methods
    add,
    copy,
    move,
    remove,
    truncate,
    draggableListeners
  }
}
