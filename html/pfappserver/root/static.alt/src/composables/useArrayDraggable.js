import { computed, nextTick, ref, toRefs, unref, watch } from '@vue/composition-api'
import uuidv4 from 'uuid/v4'

export const useArrayDraggable = (value, onChange = () => {}) => {

  const draggableRef = ref(null)

  const length = unref(value).length
  const draggableHints = ref([...Array(length).keys()].map(hint => uuidv4()))

  watch(
    () => unref(value).length,
    (lengthAfter, lengthBefore) => {
      if (!lengthBefore || !lengthAfter) {
        draggableHints.value = [...Array(lengthAfter).keys()].map(hint => uuidv4())
      }
    },
    { immediate: true }
  )

  const add = (index, newValue) => {
    return new Promise(resolve => {
      const _value = unref(value)
      onChange([..._value.slice(0, index), newValue, ..._value.slice(index)])

      const _hints = unref(draggableHints)
      draggableHints.value = [..._hints.slice(0, index), uuidv4(), ..._hints.slice(index)]

      nextTick(() => resolve())
    })
  }

  const copy = (fromIndex, toIndex) => {
    return new Promise(resolve => {
      const _value = unref(value)
      const newValue = JSON.parse(JSON.stringify(_value[fromIndex])) // dereferenced copy
      onChange([..._value.slice(0, toIndex), newValue, ..._value.slice(toIndex)])

      const _hints = unref(draggableHints)
      draggableHints.value = [..._hints.slice(0, toIndex), uuidv4(), ..._hints.slice(toIndex)]

      nextTick(() => resolve())
    })
  }

  const move = (fromIndex, toIndex) => {
    return new Promise(resolve => {
      const _value = unref(value)
      const newValue = JSON.parse(JSON.stringify(_value)) // dereferenced copy
      if (toIndex >= newValue.length) {
        var k = toIndex - newValue.length + 1
        while (k--) {
          newValue.push(undefined)
          draggableHints.value.push(undefined)
        }
      }
      newValue.splice(toIndex, 0, newValue.splice(fromIndex, 1)[0])
      onChange(newValue)

      draggableHints.value.splice(toIndex, 0, draggableHints.value.splice(fromIndex, 1)[0])

      nextTick(() => resolve())
    })
  }

  const remove = (index) => {
    return new Promise(resolve => {
      const _value = unref(value)
      onChange([..._value.slice(0, index), ..._value.slice(index + 1, _value.length)])

      const _hints = unref(draggableHints)
      draggableHints.value = [..._hints.slice(0, index), ..._hints.slice(index + 1, _hints.length)]

      nextTick(() => resolve())
    })
  }

  const truncate = () => {
    return new Promise(resolve => {
      onChange([])
      draggableHints.value = []

      nextTick(() => resolve())
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
    draggableHints,

    // methods
    add,
    copy,
    move,
    remove,
    truncate,
    draggableListeners
  }
}
