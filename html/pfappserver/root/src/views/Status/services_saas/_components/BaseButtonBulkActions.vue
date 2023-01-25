<template>
  <b-dropdown ref="buttonRef"
    variant="outline-primary" toggle-class="text-decoration-none" no-flip>
    <template #button-content>
      <slot name="default">{{ $i18n.t('{num} selected', { num: selectedItems.length }) }}</slot>
    </template>
    <b-dropdown-item @click="doRestart" @click.stop="onClick" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $i18n.t('Restart All') }}</b-dropdown-item>
  </b-dropdown>
</template>
<script>

const props = {
  selectedItems: {
    type: Array
  },
  visibleColumns: {
    type: Array
  }
}

import { computed, nextTick, ref, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const buttonRef = ref(null)

  const onClick = () => {
    nextTick(() => {
      buttonRef.value.show() // keep open on click
    })
  }

  const {
    selectedItems
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const isLoading = computed(() => $store.getters['k8s/isLoading'])
  const services = computed(() => $store.state.k8s.services)

  const doRestart = () => {
    Promise.all(
      selectedItems.value.map(({ service }) => {
        $store.dispatch('k8s/restartService', service).catch(e => e)
      })
    )
  }

  return {
    buttonRef,
    onClick,
    isLoading,
    services,
    doRestart,
  }
}

// @vue/component
export default {
  name: 'base-button-bulk-actions',
  inheritAttrs: false,
  props,
  setup
}
</script>

<style lang="scss" scoped>
  // remove bootstrap background color
  .b-table-top-row {
    background: none !important;
  }
</style>