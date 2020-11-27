import { computed, inject, provide, ref, toRefs, watch } from '@vue/composition-api'
import uuidv4 from 'uuid/v4'

export const useDraggable = (context, getValueFn, setValueFn) => {

  // consume only req'd listeners from parent,
  //  to avoid (re)exposing change/input/update listeners
  //  since these are already handled with our model.
  const { listeners: {
    dragend = () => {},
    dragleave = () => {},
    dragover = () => {},
    dragstart = () => {},
    drop = () => {}
  } = {} } = context
  const bindListeners = { // forward listeners from parent
    dragend,
    dragleave,
    dragover,
    dragstart,
    drop
  }

  const bus = inject('draggableBus', ref(false))
  if (bus.value === false) { // not (yet) provided by parent
    bus.value = { // init singleton
      sourceElement: undefined,
      sourceUUID: undefined,
      sourceIndex: undefined,
      sourceGetterFn: undefined,
      sourceSetterFn: undefined,
      targetUUID: undefined,
      targetIndex: undefined,
      targetSetterFn: undefined,
      targetPlaceholder: ref({ template: '<!-- placeholder -->' }) // @vue/component
    }
    provide('draggableBus', bus)
  }

  const UUID = uuidv4()

  const dragSourceIndex = computed(() => {
    const { sourceUUID, sourceIndex } = toRefs(bus.value)
    if (UUID === sourceUUID.value)
      return sourceIndex.value
    return -1
  })

  const dragTargetIndex = computed(() => {
    const { targetUUID, targetIndex } = toRefs(bus.value)
    if (UUID === targetUUID.value)
      return targetIndex.value
    return -1
  })

  watch(dragSourceIndex, () => {
    const { sourceElement } = toRefs(bus.value)
    if (sourceElement.value) {
      const sourceElementClone = sourceElement.value.cloneNode(true)
      sourceElementClone.removeAttribute('draggable')
      // stripe Vue's [id^="__BVID__"]
      sourceElementClone.querySelectorAll('[id^="__BVID__"]').forEach(node => node.removeAttribute('id'))
      const serializer = new XMLSerializer()
      // margins within sourceElement produce gaps in mouse drag events
      //  causing premature dragleave, use a solid overlay for event listeners.
      // @vue/component
      const dragOverListener = e => {
        e.preventDefault() && e.stopPropagation() // allow drop, stop bubbling
        if (releaseDragIndexTimeout)
          clearTimeout(releaseDragIndexTimeout)
      }
      const dragLeaveListener = e => onDragLeave(dragTargetIndex.value, e)
      const dropListener = e => onDrop(e)
      const overlay = {
        template: `<div draggable style="position:absolute;top:0;right:0;bottom:0;left:0;"/>`,
        mounted() {
          this.$el.addEventListener('dragover', dragOverListener)
          this.$el.addEventListener('dragleave', dragLeaveListener)
          this.$el.addEventListener('drop', dropListener)
        },
        beforeUnmount() {
          this.$el.removeEventListener('dragover', dragOverListener)
          this.$el.removeEventListener('dragleave', dragLeaveListener)
          this.$el.removeEventListener('drop', dropListener)
        }
      }
      const template = `<div style="position: relative;">
        ${serializer.serializeToString(sourceElementClone)}
        <overlay/>
      </div>`
      bus.value.targetPlaceholder = { components: { overlay }, template } // @vue/component
    }
  })

  const placeholderComponent = computed(() => {
    const { targetPlaceholder } = toRefs(bus.value)
    return targetPlaceholder.value
  })

  // debounce jitter caused by repetitive dragover/dragleave
  let releaseDragIndexTimeout

  const onDragStart = (index, event) => {
    event.stopPropagation()
    if (index === dragSourceIndex.value)
      return
    const { target: sourceElement, clientX: x, clientY: y } = event
    if (!document.elementFromPoint(x, y).closest('.drag-handle, *[draggable]').classList.contains('drag-handle')) { // not a handle
      event.preventDefault() // cancel drag
      bus.value.sourceElement = undefined
      bus.value.sourceUUID = undefined
      bus.value.sourceIndex = undefined
      return
    }
    bus.value.sourceElement = sourceElement
    bus.value.sourceUUID = UUID
    bus.value.sourceIndex = index
    bus.value.sourceGetterFn = getValueFn
    bus.value.sourceSetterFn = setValueFn
  }

  const onDragOver = (index, event) => {
    event.stopPropagation()
    if (index === dragSourceIndex.value) // ignore self
      return
    const {
      sourceUUID, sourceIndex, sourceElement
    } = toRefs(bus.value)
    const targetElement = event.target.closest('*[draggable]')
    if (sourceElement.value.contains(targetElement)) // ignore children
      return
    let targetIndex = index
    if (sourceUUID.value === UUID && sourceIndex.value < targetIndex)
      targetIndex++
    if (sourceUUID.value === UUID && [dragSourceIndex.value, dragSourceIndex.value + 1].includes(targetIndex)) // avoid placeholder immediately before or after self
      return
    if (releaseDragIndexTimeout)
      clearTimeout(releaseDragIndexTimeout)
    event.preventDefault() // allow drop
    bus.value.targetUUID = UUID
    bus.value.targetIndex = targetIndex
    bus.value.targetSetterFn = setValueFn
  }

  const onDragLeave = (index, event) => {
    event.stopPropagation()
    if (releaseDragIndexTimeout)
      clearTimeout(releaseDragIndexTimeout)
    if (bus.value.targetUUID === UUID) {
      releaseDragIndexTimeout = setTimeout(() => {
        bus.value.targetIndex = -1
      }, 300)
    }
  }

  const onDragEnd = (index, event) => {
    event.stopPropagation()
    bus.value.sourceIndex = -1
    bus.value.targetIndex = -1
    if (releaseDragIndexTimeout)
      clearTimeout(releaseDragIndexTimeout)
  }

  const onDrop = event => {
    event.stopPropagation()
    const {
      sourceUUID, sourceIndex, sourceGetterFn = ref(() => {}), sourceSetterFn = ref(() => {}),
      targetUUID, targetIndex, targetSetterFn = ref(() => {})
    } = toRefs(bus.value)
    const insertValue = (sourceGetterFn.value)(sourceIndex.value)
    const insertPromise = (targetSetterFn.value)(targetIndex.value, insertValue) // insert target
    Promise.resolve(insertPromise).then(() => {
      let deleteIndex = sourceIndex.value
      if (sourceUUID.value === targetUUID.value && targetIndex.value < sourceIndex.value)
        deleteIndex++
      const deletePromise = (sourceSetterFn.value)(deleteIndex, undefined) // delete source
      return Promise.resolve(deletePromise)
        .finally(() => {
          bus.value.sourceIndex = -1
          bus.value.targetIndex = -1
        })
    }).catch(() => {
      bus.value.sourceIndex = -1
      bus.value.targetIndex = -1
    })
  }

  return {
    bindListeners,
    placeholderComponent,
    dragSourceIndex,
    dragTargetIndex,
    onDragStart,
    onDragOver,
    onDragEnd,
    onDrop
  }
}

export default useDraggable
