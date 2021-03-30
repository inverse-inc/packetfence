<template>
  <b-container fluid class="base-search-input-advanced px-0">
    <b-container fluid v-for="(o, oIndex) in value" :key="oIndex"
      class="px-0"
    >
      <b-container fluid class="rc px-0 py-1 bg-secondary">
        <draggable v-model="value[oIndex].values"
          group="or" handle=".draghandle" filter=".nodrag" dragClass="sortable-drag" 
          @start="onDragStart" @end="onDragEnd"
        >
          <base-search-input-advanced-rule v-for="(i, iIndex) in value[oIndex].values" :key="iIndex"
            v-model="value[oIndex].values[iIndex]"
            :fields="fields"
            :is-drag="isDrag"
            :has-parents="value.length > 1"
            :has-siblings="value[oIndex].values.length > 1"
            :is-last-child="iIndex === value[oIndex].values.length - 1"
            @add="onAddInnerRule(oIndex)"
            @delete="onDeleteRule(oIndex, iIndex)"
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
          <a href="javascript:void(0)" class="text-nowrap text-white" @click="onAddOuterRule">{{ $t('Add "and" statement') }}</a>
        </b-container>
      </b-col>
    </b-row>
  </b-container>
</template>
<script>
const draggable = () => import('vuedraggable')
import BaseSearchInputAdvancedRule from './BaseSearchInputAdvancedRule'

const components = {
  draggable,
  BaseSearchInputAdvancedRule
}

const props = {
  value: {
    type: Array
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
    value
  } = toRefs(props)

  const { emit } = context

  const isDrag = ref(false)
  const onDragStart = () => {
    isDrag.value = true
  }
  const onDragEnd = () => {
    isDrag.value = false
    for (let i = value.value.length - 1; i >= 0; i--) {
      if (value.value[i].values.length === 0)
        value.value.splice(i, 1)
    }
  }

  const onAddInnerRule = (oIndex) => {
    let field = fields.value[0].value
    let op = null
    // clone previous sibling `field` and `op` (if exists)
    if (value.value[oIndex].values.length > 0) {
      const lIndex = value.value[oIndex].values.length - 1
      field = value.value[oIndex].values[lIndex].field
      op = value.value[oIndex].values[lIndex].op
    }
    value.value[oIndex].values.push({ field, op, value: null })    
  }

  const onAddOuterRule = () => {
    const rule = { values: [{ field: fields.value[0].value, op: null, value: null }] }
    if (value.value && value.value.constructor === Array)
      emit('input', [...value.value, rule])
    else
      emit('input', [rule])
  }

  const onDeleteRule = (oIndex, iIndex) => {
    if (value.value[oIndex].values.length === 1) {
      if (value.value.length > 1)
        value.value.splice(oIndex, 1)
    }
    else
      value.value[oIndex].values.splice(iIndex, 1)
  }

  return { 
    isDrag,
    onDragStart,
    onDragEnd,
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