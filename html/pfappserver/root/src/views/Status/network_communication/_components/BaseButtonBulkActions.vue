<template>
  <b-dropdown variant="outline-primary" toggle-class="text-decoration-none" no-flip>
    <template #button-content>
      <slot name="default">{{ $t('{num} selected', { num: selectedItems.length }) }}</slot>
    </template>
    <b-dropdown-item @click="onBulkExport">
      <icon class="position-absolute mt-1" name="file-export" />
      <span class="ml-4">{{ $t('Export to CSV') }}</span>
    </b-dropdown-item>
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

import { toRefs } from '@vue/composition-api'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'

const setup = (props, context) => {

  const {
    selectedItems,
    visibleColumns
  } = toRefs(props)

  const { root: { $router } = {} } = context

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  return {
    onBulkExport,
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

<style lang="scss">
  // remove bootstrap background color
  .b-table-top-row {
    background: none !important;
  }
</style>