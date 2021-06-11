<template>
  <b-container fluid class="px-1">
    <b-row class="bg-white rc align-items-center m-0 p-1 isdrag">
      <b-input-group class="mr-1">
        <b-input-group-prepend v-if="icon || hasParents || hasSiblings"
          class="p-0"
          is-text>
          <icon  v-if="icon"
            :name="icon" />
          <span v-if="hasParents || hasSiblings"
            class="draghandle"
            v-b-tooltip.hover.right.d300 :title="$t('Click & drag statement to reorder')">
            <icon name="th" />
          </span>
        </b-input-group-prepend>
        <b-form-select v-model="value.field" :disabled="disabled" :options="fieldOptions" />
        <b-form-select class="mr-1" v-model="value.op" :disabled="disabled" :options="operatorOptions" />
        <component :is="valueComponentIs"
          v-bind="valueComponentProps"
          v-model="value.value"
        />
        <b-input-group-append v-if="hasParents || (hasSiblings && !isDrag)">
          <b-button
            class="ml-auto nodrag" variant="link"
            v-b-tooltip.hover.left.d300 :disabled="disabled" :title="$t('Delete statement')"
            @click="onDeleteRule">
            <icon name="trash-alt" />
          </b-button>
        </b-input-group-append>
      </b-input-group>
    </b-row>
    <b-row class="mx-auto isdrag">
      <b-col cols="1"></b-col>
      <b-col cols="1" class="py-0 bg-white" style="min-width:60px;">
        <div class="mx-auto text-center text-nowrap font-weight-bold">{{ $t('or') }}</div>
      </b-col>
    </b-row>
    <b-row v-if="isLastChild && !isDrag"
      class="mx-auto nodrag">
      <b-col cols="12" class="bg-white rc">
        <b-container class="mx-0 px-1 py-1">
          <span v-if="disabled"
            class="text-nowrap">{{ $t('Add "or" statement') }}</span>
          <a v-else
            href="javascript:void(0)" class="text-nowrap" @click="onAddRule">{{ $t('Add "or" statement') }}</a>
        </b-container>
      </b-col>
    </b-row>
  </b-container>
</template>

<script>
import {
  BaseInput,
  BaseInputChosenOne,
  BaseInputGroupDateTime,
  BaseInputGroupMultiplier,
  BaseInputNumber
} from '@/components/new/'

const props = {
  value: {
    type: Object
  },
  hasParents: {
    type: Boolean
  },
  hasSiblings: {
    type: Boolean
  },
  isLastChild: {
    type: Boolean
  },
  isDrag: {
    type: Boolean
  },
  fields: {
    type: Array
  },
  disabled: {
    type: Boolean
  }
}

import { computed, toRefs } from '@vue/composition-api'
import {
  pfSearchConditionValue,
  pfSearchOperatorsForTypes,
  pfSearchValuesForOperator,
  pfConditionOperators,
} from '@/globals/pfSearch'
import i18n from '@/utils/locale'

const setup = (props, context) => {
  const {
    disabled,
    fields,
    value
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  const field = computed(() => {
    const index = fields.value.findIndex(field => value.value.field === field.value)
    if (index >= 0)
      return fields.value[index]
  })

  const icon = computed(() => {
    const { icon } = field.value || {}
    return icon
  })

  const fieldOptions = computed(() => {
    return fields.value
      .map(field => ({ ...field, text: i18n.t(field.text) }))
  })

  const operatorOptions = computed(() => {
    const { types } = field.value || {}
    if (types) {
      return pfSearchOperatorsForTypes(types)
        .map((operator, index, operators) => {
          if (index === 0 && !operators.includes(value.value.op))
            value.value.op = operator // select the first valid operator
          return { value: operator, text: i18n.t(operator.replace(/_/g, ' ')) }
        })
    }
  })

  const valueComponentIs = computed(() => {
    const { types } = field.value || {}
    if (types) {
      for (const t of types) {
        let operators = pfConditionOperators[t]
        for (const op of Object.keys(operators)) {
          if (op === value.value.op) {
            switch (operators[op]) {
              case pfSearchConditionValue.SELECT:
                return BaseInputChosenOne
                // break
              case pfSearchConditionValue.DATETIME:
                return BaseInputGroupDateTime
                // break
              case pfSearchConditionValue.PREFIXMULTIPLE:
                return BaseInputGroupMultiplier
                // break
              case pfSearchConditionValue.INTEGER:
                return BaseInputNumber
                // break
              case pfSearchConditionValue.TEXT:
              default:
                return BaseInput
                // break
            }
          }
        }
      }
    }
    return undefined
  })

  const valueComponentProps = computed(() => {
    const { types } = field.value || {}
    if (types) {
      const options = pfSearchValuesForOperator(types, value.value.op, $store) || []
      if (options.length && options.findIndex(v => v.value === value.value.value) < 0)
        value.value.value = options[0].value // select the first valid option
      return { disabled, options }
    }
    return { disabled }
  })

  const onAddRule = () => emit('add')
  const onDeleteRule = () => emit('delete')

  return {
    icon,
    fieldOptions,
    operatorOptions,
    valueComponentIs,
    valueComponentProps,
    onAddRule,
    onDeleteRule
  }
}

// @vue/component
export default {
  name: 'base-search-input-advanced-rule',
  inheritAttrs: false,
  props,
  setup
}
</script>

<style lang="scss">
.isdrag {
  display: flex;
  flex-wrap: wrap;
  & > .input-group {
    & > * {
      flex-grow: 1 !important;
      flex-shrink: 1 !important;
    }
    & > .input-group-append,
    & > .input-group-prepend {
      flex-grow: 0 !important;
      flex-shrink: 0 !important;
    }
  }
}
</style>