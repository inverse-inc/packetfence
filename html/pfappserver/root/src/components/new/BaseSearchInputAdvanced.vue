<template>
  <b-container fluid class="base-search-input-advanced px-0">
    <b-container fluid v-for="(o, oIndex) in value.values" :key="oIndex"
      class="px-0"
    >
      <b-container fluid class="rc px-0 py-1 bg-secondary">
        <draggable v-model="value.values[oIndex].values"
          group="or" handle=".draghandle" filter=".nodrag" dragClass="sortable-drag"
          @start="onDragStart" @end="onDragEnd" :move="onMove"
        >
          <base-search-input-advanced-rule v-for="(i, iIndex) in value.values[oIndex].values" :key="iIndex"
            v-model="value.values[oIndex].values[iIndex]"
            :disabled="disabled"
            :fields="fields"
            :is-drag="isDrag"
            :has-parents="value.values.length > 1"
            :has-siblings="value.values[oIndex].values.length > 1"
            :is-last-child="iIndex === value.values[oIndex].values.length - 1"
            @add="onAddInnerRule(oIndex)"
            @delete="onDeleteRule(oIndex, iIndex)"
            @search="$emit('search', $event)"
          />
        </draggable>
      </b-container>
      <b-row class="mx-auto">
        <b-col cols="1" />
        <b-col cols="1" class="py-0 bg-secondary" style="min-width:60px;">
          <div class="mx-auto text-center text-nowrap text-white font-weight-bold">{{ $t('and') }}</div>
        </b-col>
      </b-row>
    </b-container>
    <b-row class="mx-auto">
      <b-col cols="12" class="bg-secondary rc">
        <b-container class="mx-0 px-1 py-1">
          <span v-if="disabled"
            class="text-nowrap text-white">{{ $t('Add "and" statement') }}</span>
          <a v-else
            href="javascript:void(0)" class="text-nowrap text-white" @click="onAddOuterRule">{{ $t('Add "and" statement') }}</a>
        </b-container>
      </b-col>
    </b-row>
  </b-container>
</template>
<script>
const draggable = () => import(/* webpackChunkName: "Libs" */ 'vuedraggable')
import BaseSearchInputAdvancedRule from './BaseSearchInputAdvancedRule'

const components = {
  draggable,
  BaseSearchInputAdvancedRule
}

const props = {
  value: {
    type: Object
  },
  fields: {
    type: Array
  },
  disabled: {
    type: Boolean
  }
}

import { ref, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    fields,
    value,
    disabled
  } = toRefs(props)

  const { emit } = context

  const isDrag = ref(false)
  const onDragStart = () => {
    isDrag.value = true
  }
  const onDragEnd = () => {
    isDrag.value = false
    for (let i = value.value.values.length - 1; i >= 0; i--) {
      if (value.value.values[i].values.length === 0)
        value.value.values.splice(i, 1)
    }
  }
  const onMove = () => {
    if (disabled.value)
      return false
  }

  const onAddInnerRule = (oIndex) => {
    let field = fields.value[0].value
    let op = null
    // clone previous sibling `field` and `op` (if exists)
    if (value.value.values[oIndex].values.length > 0) {
      const lIndex = value.value.values[oIndex].values.length - 1
      field = value.value.values[oIndex].values[lIndex].field
      op = value.value.values[oIndex].values[lIndex].op
    }
    value.value.values[oIndex].values.push({ field, op, value: null })
  }

  const onAddOuterRule = () => {
    const rule = { op: 'or', values: [{ field: fields.value[0].value, op: null, value: null }] }
    if (value.value.values && value.value.values.constructor === Array)
      emit('input', { op: 'and', values: [...value.value.values, rule] })
    else
      emit('input', { op: 'and', values: [rule] })
  }

  const onDeleteRule = (oIndex, iIndex) => {
    if (value.value.values[oIndex].values.length === 1) {
      if (value.value.values.length > 1)
        value.value.values.splice(oIndex, 1)
    }
    else
      value.value.values[oIndex].values.splice(iIndex, 1)
  }

  return {
    isDrag,
    onDragStart,
    onDragEnd,
    onMove,
    onAddInnerRule,
    onAddOuterRule,
    onDeleteRule
  }
}

// @vue/component
export default {
  name: 'base-search-input-advanced',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

<style lang="scss">
.base-search-input-advanced {
  .draghandle {
    line-height: 1em;
  }
  .rc, .rc-t, .rc-l, .rc-tl {
    border-top-left-radius: $input-border-radius;
  }
  .rc, .rc-t, .rc-r, .rc-tr {
    border-top-right-radius: $input-border-radius;
  }
  .rc, .rc-b, .rc-r, .rc-br {
    border-bottom-right-radius: $input-border-radius;
  }
  .rc, .rc-b .rc-l, .rc-bl {
    border-bottom-left-radius: $input-border-radius;
  }
  .sortable-drag .nodrag {
    display: none;
  }
}
</style>