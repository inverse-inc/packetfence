<template>
  <b-dropdown size="sm" variant="link" no-caret right
    :disabled="disabled"
    @hidden="onCommit"
  >
    <template v-slot:button-content>
      <icon name="columns"
        v-b-tooltip.hover.top.d300.window :title="$t('Visible Columns')"></icon>
    </template>
    <template v-for="column in columns">
      <template v-if="column.label">
        <b-dropdown-item v-if="column.locked || column.required"
          :key="column.key" disabled>
          <icon class="position-absolute mt-1" name="thumbtack"></icon>
          <span class="ml-4">{{ $t(column.label) }}</span>
        </b-dropdown-item>
        <a v-else
          href="javascript:void(0)" class="dropdown-item"
          :key="column.key"
          @click.stop="onToggle(column)"
        >
          <icon class="position-absolute mt-1" name="check" v-show="column.visible"></icon>
          <span class="ml-4">{{ $t(column.label) }}</span>
        </a>
      </template>
    </template>
  </b-dropdown>
</template>
<script>
const props = {
  value: {
    type: Array
  },
  disabled: {
    type: Boolean
  }
}

import { ref, toRefs, watch } from '@vue/composition-api'

const setup = (props, context) => {
  const {
    value
  } = toRefs(props)

  const { emit } = context

  const columns = ref([])
  watch(value, () => {
    columns.value = JSON.parse(JSON.stringify(value.value)) // dereference
  }, { deep: true, immediate: true })
  let flag = false

  // only emit when dropdown is closed (debounce)
  const onCommit = () => {
    if (flag)
      emit('input', JSON.parse(JSON.stringify(columns.value))) // dereference
    flag = false
  }

  const onToggle = column => {
    const _columns = columns.value
      .map(_column => {
        if (_column.key === column.key) {
            _column.visible = !_column.visible
            flag = true
        }
        return _column
      })
    columns.value = _columns
  }

  return {
    columns,
    onCommit,
    onToggle
  }
}

// @vue/component
export default {
  name: 'base-search-input-columns',
  inheritAttrs: false,
  props,
  setup
}
</script>
