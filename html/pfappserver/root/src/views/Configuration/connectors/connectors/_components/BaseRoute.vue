<template>
  <b-row class="w-100" align-v="start" no-gutters>
    <b-col cols="4" class="base-flex-wrap pr-1">
      <base-input
        :namespace="`${namespace}.destination`"
        :placeholder="$t('Destination (e.g. 10.20.0.0/16)')"
      />
    </b-col>
    <b-col cols="4" class="base-flex-wrap pr-1">
      <base-input
        :namespace="`${namespace}.gateway`"
        :placeholder="$t('Gateway (optional)')"
      />
    </b-col>
    <b-col cols="4" class="base-flex-wrap">
      <base-input-chosen-one
        :namespace="`${namespace}.interface`"
        :placeholder="$t('Interface (optional)')"
        :options="interfaceOptions"
        :taggable="true"
        :tag-placeholder="$t('Use this interface name')"
      />
    </b-col>
  </b-row>
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

import { computed, inject, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { useInputMetaProps } from '@/composables/useMeta'
import { useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = () => {
  // Offer the interfaces reported by the connector host plus the VLAN
  // interfaces configured in this form ("<parent>.<vlan>", which may not
  // exist on the host yet); anything else can still be typed in (taggable).
  const form = inject('form', ref({}))
  const hostInterfaces = inject('connectorHostInterfaces', ref([]))
  const interfaceOptions = computed(() => {
    const mains = new Set((hostInterfaces.value || []).filter(({ main }) => main).map(({ name }) => name))
    const names = new Set((hostInterfaces.value || []).map(({ name }) => name))
    for (const { parent, vlan } of (form.value.interfaces || [])) {
      if (parent && vlan)
        names.add(`${parent}.${vlan}`)
    }
    return [...names].sort()
      .map(name => ({ text: mains.has(name) ? `${name} (${i18n.t('main')})` : name, value: name }))
  })

  return {
    interfaceOptions
  }
}

// @vue/component
export default {
  name: 'base-route',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
