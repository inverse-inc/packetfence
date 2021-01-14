<template>
  <base-form-group
    :label-cols="labelCols"
    :column-label="columnLabel"
    :text="$i18n.t('The attribute to filter on')"
    class="base-form-group-basic-filter"
  >
    <base-input-chosen-one namespace="basic_filter_type"
      class="mr-1" />
    <component :is="valueComponent"
      v-bind="valueProps"
      namespace="basic_filter_value" />
  </base-form-group>
</template>
<script>
import {
  BaseFormGroup,

  BaseInput,
  BaseInputChosenOne
} from '@/components/new/'
import BaseInputChosenOneRole from '@/views/Configuration/roles/_components/BaseInputChosenOneRole'
import BaseInputChosenOneSearchableUser from '@/views/Users/_components/new/BaseInputChosenOneSearchableUser'

const components = {
  BaseFormGroup,

  BaseInput,
  BaseInputChosenOne,
  BaseInputChosenOneRole,
  BaseInputChosenOneSearchableUser
}

import { computed, reactive } from '@vue/composition-api'
import { useFormGroupProps as props } from '@/composables/useFormGroup'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'

const setup = (props, context) => {

  const metaProps = useInputMeta(reactive({ namespace: 'basic_filter_type' }), context)

  const {
    value: basicFilterType
  } = useInputValue(metaProps, context)

  const valueComponent = computed(() => {
    switch(basicFilterType.value) {
      case 'node_info.mac':
        return BaseInput
        // break
      case 'node_info.pid':
        return BaseInputChosenOneSearchableUser
        // break
      case 'node_info.category':
        return BaseInputChosenOneRole
        // break
      default:
        return undefined
    }
  })

  const valueProps = computed(() => {
    switch(basicFilterType.value) {
      case 'node_info.pid':
        return {
          taggable: true // allow any pid
        }
        // break
      default:
        return {}
    }
  })

  return {
    valueComponent,
    valueProps
  }

}

// @vue/component
export default {
  name: 'base-form-group-basic-filter',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group-basic-filter {
  & > .form-row {
    & > .col,
    & > .col > .input-group > * {
      flex-grow: 1;
      flex-shrink: 0;
    }
  }
}
</style>
