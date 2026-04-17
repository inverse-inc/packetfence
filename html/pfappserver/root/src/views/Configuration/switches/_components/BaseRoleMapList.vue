<template>
  <div ref="scrollContainer" class="role-map-list" @scroll="onScroll"
    :style="{ maxHeight: maxHeight + 'px', overflowY: 'auto' }">
    <div :style="{ height: topSpacerHeight + 'px' }"></div>
    <slot v-for="role in visibleRoles" :role="role" />
    <div :style="{ height: bottomSpacerHeight + 'px' }"></div>
  </div>
</template>

<script>
import { computed, onMounted, onBeforeUnmount, ref, watch } from '@vue/composition-api'

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

    const visibleCount = computed(() => {
      return Math.ceil(props.maxHeight / props.itemHeight) + BUFFER_ITEMS * 2
    })

    const startIndex = computed(() => {
      const index = Math.floor(scrollTop.value / props.itemHeight) - BUFFER_ITEMS
      return Math.max(0, index)
    })

    const endIndex = computed(() => {
      return Math.min(props.roles.length, startIndex.value + visibleCount.value)
    })

    const visibleRoles = computed(() => {
      return props.roles.slice(startIndex.value, endIndex.value)
    })

    const topSpacerHeight = computed(() => {
      return startIndex.value * props.itemHeight
    })

    const bottomSpacerHeight = computed(() => {
      return (props.roles.length - endIndex.value) * props.itemHeight
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
