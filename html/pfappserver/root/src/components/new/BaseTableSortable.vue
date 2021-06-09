<template>
  <b-table-simple
    v-bind="$attrs"
    aria-multiselectable="true"
    class="base-table-sortable b-table"
    :class="{
      'b-table-selectable': selectable
    }"
    :aria-busy="busy"
  >
    <b-thead>
      <b-th aria-colindex="1" class="text-center" style="width: 40px;"
        v-b-tooltip.hover.top.d300 :title="$t('Drag and drop items to reorder.')"
      ><icon name="sort" /></b-th>
      <b-th v-for="(field, fIndex) in fields" :key="field.key"
        :aria-colindex="fIndex + 2" :class="field.class" :style="field.thStyle">
        <slot :name="`head(${field.key})`" v-bind="{ label: field.label, column: field.key, field, isFoot: false }">{{ $t(field.label) }}</slot>
      </b-th>
    </b-thead>
    <!-- <b-tbody> --><draggable v-model="dragItems"
      tag="tbody" handle=".drag-handle"
      :class="{[`cursor-grabbing`]: dragging === true}"
      :move="dragMove"
      @start="dragging = true"
      @end="dragging = false"
      @change="dragChanged"
    >
      <b-tr v-if="items.length === 0"
        class="b-table-empty-row"
      >
        <b-td aria-colindex="1" :colspan="fields.length + 1">
          <div role="alert" aria-live="polite">
            <slot name="empty" v-bind="{ isLoading: busy }"/>
          </div>
        </b-td>
      </b-tr>
      <b-tr  v-for="(item, iIndex) in items" :key="`row-${iIndex}`"
        tabindex="0"
        :aria-selected="(rowsSelected[iIndex]) ? 'true' : 'false'"
        :class="{
          'b-table-row-selected': rowsSelected[iIndex],
          'table-active': rowsSelected[iIndex]
        }"
        @click="onRowClicked(iIndex)"
      >
        <b-td aria-colindex="1" class="p-0 text-center"
          :class="{
            'drag-handle': !item.not_sortable
          }"
          @click.stop.prevent
        >
          <span v-if="item.not_sortable || items.length <= 1"
            v-b-tooltip.hover.top.d300 :title="$t('This item can not be reordered.')">
            <icon name="lock" />
          </span>
          <span v-else
            v-b-tooltip.hover.top.d300 :title="$t('Drag and drop item to reorder.')">
            <icon name="th" />
          </span>
        </b-td>
        <b-td v-for="(field, fIndex) in fields" :key="`${field.key}-${iIndex}`"
          :aria-colindex="fIndex + 2" :class="field.tdClass || field.class">
          <slot :name="`cell(${field.key})`" v-bind="{
            item, index: iIndex, field,
            unformatted: item[field.key],
            value: (field.formatter) ? field.formatter(item[field.key]) : item[field.key],
            rowSelected: rowsSelected[iIndex]
          }">{{ (field.formatter) ? field.formatter(item[field.key]) : item[field.key] }}</slot>
        </b-td>
      </b-tr>
    </draggable><!-- </b-tbody> -->

  </b-table-simple>
</template>
<script>
const draggable = () => import('vuedraggable')

const components = {
  draggable
}

const props = {
  fields: {
    type: Array
  },
  items: {
    type: Array
  },
  busy: {
    type: Boolean
  },
  selectable: {
    type: Boolean
  }
}

import { ref, toRefs, watch } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    items
  } = toRefs(props)

  const { emit } = context

  const dragging = ref(false)
  const dragChanged = e => {
      if (e.moved) {
        const oldIndex = e.moved.oldIndex - 1
        const newIndex = e.moved.newIndex - 1
        const _items = JSON.parse(JSON.stringify(items.value))
        const tmp = _items[oldIndex]
        if (oldIndex > newIndex) {
          // shift down (not swapped)
          for (let i = oldIndex; i > newIndex; i--) {
            _items[i] = _items[i - 1]
          }
        } else {
          // shift up (not swapped)
          for (let i = oldIndex; i < newIndex; i++) {
            _items[i] = _items[i + 1]
          }
        }
        _items[newIndex] = tmp
        emit('items-sorted', _items)
      }
  }
  const dragMove = e => {
    const { draggedContext: { futureIndex } = {} } = e
    const { [futureIndex - 1]: { not_sortable = false } = {} } = items.value
    return !not_sortable // prevent move onto not_sortable
  }
  const dragItems = ref(items.value)

  const rowsSelected = ref([])
  watch(items, () => {
    rowsSelected.value = []
    emit('row-selected', [])
    dragItems.value = items.value
  }, { deep: true })

  const selectRow = index => {
    rowsSelected.value[index] = !rowsSelected.value[index]
    emit('row-selected', items.value.filter((_, i) => rowsSelected.value[i]))
  }

  const unselectRow = index => {
    rowsSelected.value[index] = false
    emit('row-selected', items.value.filter((_, i) => rowsSelected.value[i]))
  }

  const selectAllRows = () => {
    rowsSelected.value = items.value.map(() => true)
    emit('row-selected', items.value)
  }

  const clearSelected = () => {
    rowsSelected.value = []
    emit('row-selected', [])
  }

  const onRowClicked = index => {
    emit('row-clicked', items.value[index])
  }

  return {
    rowsSelected,
    selectRow,
    unselectRow,
    selectAllRows,
    clearSelected,
    onRowClicked,

    dragging,
    dragChanged,
    dragMove,
    dragItems
  }
}

// @vue/component
export default {
  name: 'base-table-sortable',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-table-sortable {
  & > tbody > tr > td.drag-handle {
    cursor: grab;
  }
}
</style>
