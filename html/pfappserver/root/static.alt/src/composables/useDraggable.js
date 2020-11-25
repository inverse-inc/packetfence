import { inject, nextTick, provide, ref, toRefs, unref, watch } from '@vue/composition-api'

/*
 *  CSS flex-box layout can stack elements either vertical (above/below) or horizontal (left/right)
 *  2 drop zones accomodate both layouts:
 *    previous: within triangle @top-left (returns true)
 *    next: within triangle @bottom-right (returns false)
 */
const isMouseOverNext = (event) => {
  const { target, x, y } = event
  const { width, height, top, left } = target.closest('*[draggable]').getBoundingClientRect()
  const ar = width / height
  const dx = x - left
  const dy = height - dx / ar
  return (y - top > dy) // false: previous, true: next
}

export const useDraggable = (props) => {

  const {
    namespace,
    value
  } = toRefs(props)

  const bus = inject('draggableBus', ref(false))
  if (bus.value === false) { // no parent provide
    bus.value = {} // init
    provide('draggableBus', bus)
  }

  const dragSourceIndex = ref(-1)
  const dragTargetIndex = ref(-1)
  let releaseDragIndexTimeout

  const onDragStart = (index, event) => {
    const { target: sourceElement, clientX: x, clientY: y } = event
    if (!document.elementFromPoint(x, y).closest('.drag-handle, *[draggable]').classList.contains('drag-handle')) { // not a handle
      event.preventDefault() // cancel drag
      bus.value = {}
      return
    }
    dragSourceIndex.value = index
    const { values: { [index]: childValue } = {} } = value.value
    bus.value = Object.assign({}, childValue) // dereference
  }

  const onDragOver = (index, event) => {
    if (index === dragSourceIndex.value) // ignore self
      return
    event.preventDefault() // always allow drop
    event.stopPropagation() // don't bubble up
    const isNext = isMouseOverNext(event) // determine mouse position over @target
    if (releaseDragIndexTimeout)
      clearTimeout(releaseDragIndexTimeout)
    if (isNext)
      dragTargetIndex.value = index + 1
    else
      dragTargetIndex.value = index
  }

  const onDragLeave = (index, event) => {
    if (releaseDragIndexTimeout)
      clearTimeout(releaseDragIndexTimeout)
    releaseDragIndexTimeout = setTimeout(() => {
      dragTargetIndex.value = -1
    }, 100)
  }

  const onDragEnd = (index, event) => {
    //dragSourceIndex.value = -1
    //dragTargetIndex.value = -1
    if (releaseDragIndexTimeout)
      clearTimeout(releaseDragIndexTimeout)
  }

  const onDrop = (index, event) => {
console.log('onDrop', {index, event})

  }

  return {
    bus,
    dragSourceIndex,
    dragTargetIndex,
    onDragStart,
    onDragOver,
    onDragLeave,
    onDragEnd,
    onDrop
  }
}

export default useDraggable
