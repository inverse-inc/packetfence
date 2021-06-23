<template>
  <b-button type="button" :size="size" :disabled="disabled || data.length === 0" :variant="variant" @click="onDownload">
    <icon name="file-export" class="mr-2"></icon>
    <template >
      <slot>{{ $t('Export to CSV') }}</slot>
    </template>
  </b-button>
</template>

<script>

const props = {
  disabled: {
    type: Boolean
  },
  variant: {
    type: String,
    default: 'outline-primary'
  },
  columns: {
    type: Array
  },
  data: {
    type: Array
  },
  filename: {
    type: String,
    default: 'export.csv'
  },
  size: {
    type: String,
    default: 'sm'
  }
}

import { computed, toRefs } from '@vue/composition-api'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'

const setup = (props) => {

  const {
    columns,
    data,
    filename
  } = toRefs(props)

  const visibleColumns = computed(() => columns.value.filter(column => !column.locked && column.visible))

  const onDownload = () => {
    const csv = useTableColumnsItems(visibleColumns.value, data.value)
    useDownload(filename.value, csv, 'text/csv')
  }

  return {
    onDownload
  }
}

// @vue/component
export default {
  name: 'base-button-export-csv',
  inheritAttrs: false,
  props,
  setup
}
</script>
