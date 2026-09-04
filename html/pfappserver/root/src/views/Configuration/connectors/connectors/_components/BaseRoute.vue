<template>
  <b-row class="w-100" align-v="center" no-gutters>
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
import { useInputMetaProps } from '@/composables/useMeta'
import { useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = () => {
  // Offer the connector's own VLAN interfaces ("<parent>.<vlan>") as choices;
  // any other host interface can still be typed in (taggable).
  const form = inject('form', ref({}))
  const interfaceOptions = computed(() => (form.value.interfaces || [])
    .filter(({ parent, vlan }) => parent && vlan)
    .map(({ parent, vlan }) => `${parent}.${vlan}`)
    .map(name => ({ text: name, value: name }))
  )

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
