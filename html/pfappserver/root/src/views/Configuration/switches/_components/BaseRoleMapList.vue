<template>
  <div ref="scrollContainer" class="role-map-list" @scroll="onScroll"
    :style="{ maxHeight: maxHeight + 'px', overflowY: 'auto' }">
    <div :style="{ height: topSpacerHeight + 'px' }"></div>
    <div v-for="role in visibleRoles" :key="role"
      :data-role="role" class="role-map-list-row">
      <slot :role="role" />
    </div>
    <div :style="{ height: bottomSpacerHeight + 'px' }"></div>
  </div>
</template>

<script>
import { computed, onMounted, onUpdated, onBeforeUnmount, ref, watch } from '@vue/composition-api'

const ITEM_HEIGHT = 57
const BUFFER_ITEMS = 10

export default {
  name: 'base-role-map-list',
  props: {
    roles: {
      type: Array,
      default: () => []
    },
    itemHeight: {
      type: Number,
      default: ITEM_HEIGHT
    },
    maxHeight: {
      type: Number,
      default: 600
    }
  },
  setup(props) {
    const scrollContainer = ref(null)
    const scrollTop = ref(0)
    const measuredHeights = ref(Object.create(null))

    let resizeObserver = null
    const observedElements = new Set()

    const onResize = (entries) => {
      const next = { ...measuredHeights.value }
      let changed = false
      for (const entry of entries) {
        const role = entry.target.dataset.role
        if (!role) continue
        const box = entry.borderBoxSize && entry.borderBoxSize[0]
        const h = box ? box.blockSize : entry.contentRect.height
        if (h > 0 && next[role] !== h) {
          next[role] = h
          changed = true
        }
      }
      if (changed) measuredHeights.value = next
    }

    const syncObservations = () => {
      if (!resizeObserver || !scrollContainer.value) return
      const rows = scrollContainer.value.querySelectorAll('.role-map-list-row')
      const currentSet = new Set(rows)
      for (const el of observedElements) {
        if (!currentSet.has(el)) {
          resizeObserver.unobserve(el)
          observedElements.delete(el)
        }
      }
      for (const el of rows) {
        if (!observedElements.has(el)) {
          resizeObserver.observe(el)
          observedElements.add(el)
        }
      }
    }

    onMounted(() => {
      if (typeof ResizeObserver !== 'undefined') {
        resizeObserver = new ResizeObserver(onResize)
        syncObservations()
      }
    })

    onUpdated(() => {
      syncObservations()
    })

    onBeforeUnmount(() => {
      if (resizeObserver) {
        resizeObserver.disconnect()
        resizeObserver = null
      }
      observedElements.clear()
    })

    const offsets = computed(() => {
      const arr = new Array(props.roles.length + 1)
      arr[0] = 0
      for (let i = 0; i < props.roles.length; i++) {
        const h = measuredHeights.value[props.roles[i]] || props.itemHeight
        arr[i + 1] = arr[i] + h
      }
      return arr
    })

    const totalHeight = computed(() => {
      const arr = offsets.value
      return arr[arr.length - 1] || 0
    })

    const findIndexAtOffset = (pos) => {
      const arr = offsets.value
      let lo = 0
      let hi = arr.length - 1
      while (lo < hi) {
        const mid = (lo + hi + 1) >> 1
        if (arr[mid] <= pos) lo = mid
        else hi = mid - 1
      }
      return lo
    }

    const startIndex = computed(() => {
      const i = findIndexAtOffset(scrollTop.value)
      return Math.max(0, i - BUFFER_ITEMS)
    })

    const endIndex = computed(() => {
      const i = findIndexAtOffset(scrollTop.value + props.maxHeight)
      return Math.min(props.roles.length, i + BUFFER_ITEMS + 1)
    })

    const visibleRoles = computed(() => {
      return props.roles.slice(startIndex.value, endIndex.value)
    })

    const topSpacerHeight = computed(() => offsets.value[startIndex.value] || 0)

    const bottomSpacerHeight = computed(() => {
      return totalHeight.value - (offsets.value[endIndex.value] || 0)
    })

    const onScroll = () => {
      if (scrollContainer.value) {
        scrollTop.value = scrollContainer.value.scrollTop
      }
    }

    watch(() => props.roles, () => {
      scrollTop.value = 0
      if (scrollContainer.value) {
        scrollContainer.value.scrollTop = 0
      }
    })

    return {
      scrollContainer,
      visibleRoles,
      topSpacerHeight,
      bottomSpacerHeight,
      onScroll
    }
  }
}
</script>
