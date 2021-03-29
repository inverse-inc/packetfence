<template>
  <div>
    <div class="base-trigger-event base-flex-wrap" align-v="center">
      <base-input-chosen-one ref="typeComponentRef"
        :namespace="`${namespace}.type`"
        :options="typeOptions"
      />
      <component :is="valueComponent" ref="valueComponentRef"
        :namespace="`${namespace}.value`"
        :options="valueOptions"
      />
    </div>
    <template v-if="hasFingerbankNetworkBehaviorPolicy">
      <small>{{ $i18n.t('Fingerbank Network Behaviour Policy') }}</small>
      <base-input-chosen-one
        :namespace="`${namespace}.fingerbank_network_behavior_policy`"
        :options="fingerbankNetworkBehaviorPolicies"
      />
    </template>
  </div>
</template>
<script>
import {
  BaseInput,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputChosenOne
}

import { computed, inject, nextTick, ref, unref, watch } from '@vue/composition-api'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useNamespaceMetaAllowed } from '@/composables/useMeta'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent
} from '@/globals/pfField'
import {
  triggerCategories,
  triggerFields,
  fingerbankNetworkBehaviorPolicyTypes
} from '../config'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    value: inputValue,
    onChange
  } = useInputValue(metaProps, context)

  const { root: { $store } = {} } = context

  const typeComponentRef = ref(null)
  const valueComponentRef = ref(null)

  const type = computed(() => {
    const { type } = inputValue.value || {}
    return type
  })

  watch(type, () => { // when `type` is mutated
    const { isFocus = false } = typeComponentRef.value
    if (isFocus) { // and `type` isFocus
      onChange({ ...unref(inputValue), value: undefined }) // clear `value`

      nextTick(() => {
        const { doFocus = () => {} } = valueComponentRef.value || {}
        doFocus() // focus `value` component
      })
    }
  })

  const meta = inject('meta', ref({}))
  const valueOptions = ref([])
  watch(type, () => {
    valueOptions.value = useNamespaceMetaAllowed(`triggers.0.${type.value}`, meta)
      .sort((a, b) => a.text.localeCompare(b.text))
  }, { immediate: true })

  const typeOptions = Object.keys(triggerFields)
    .filter(field => {
      const { category } = triggerFields[field]
      return category === triggerCategories.EVENT
    })
    .map(value => {
      const { text, types } = triggerFields[value] || {}
      return { value, text, types }
    })

  const valueComponent = computed(() => {
    const { type } = unref(inputValue) || {}
    const { types = [] } = triggerFields[type] || {}
    for (let t = 0; t < types.length; t++) {
      let type = types[t]
      let component = fieldTypeComponent[type]
      switch (component) {
        case componentType.SELECTONE:
          return BaseInputChosenOne
          // break

        case componentType.SUBSTRING:
          return BaseInput
          // break

        case componentType.HIDDEN:
        case componentType.NONE:
          return undefined
          // break

        default:
          // eslint-disable-next-line
          console.error(`Unhandled pfComponentType '${component}' for pfFieldType '${type}'`)
      }
    }
  })

  const fingerbankNetworkBehaviorPolicies = computed(() => {
    return $store.dispatch('$_network_behavior_policies/all')
      .then(policies => {
        return policies.map(policy => ({ text: policy.description, value: policy.id }))
      })
  })
  const hasFingerbankNetworkBehaviorPolicy = computed(() => {
    const { type, value } = inputValue.value || {}
    return type === 'internal' 
      && fingerbankNetworkBehaviorPolicyTypes.includes(value)
  })
  watch(hasFingerbankNetworkBehaviorPolicy, () => { // when policy requirement changes
    if (!hasFingerbankNetworkBehaviorPolicy.value) { // and policy is no longer required
      const { type, value } = inputValue.value || {}  
      onChange({ type, value }) // clear policy
    }
  })

  return {
    typeComponentRef,
    typeOptions,
    valueComponent,
    valueComponentRef,
    valueOptions,
    fingerbankNetworkBehaviorPolicies,
    hasFingerbankNetworkBehaviorPolicy
  }
}

// @vue/component
export default {
  name: 'base-trigger-event',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
