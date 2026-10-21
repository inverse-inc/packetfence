<template>
  <b-row>
    <b-col cols="4" class="base-flex-wrap">
      <base-input-chosen-one
        :namespace="`${namespace}.domain`"
        :placeholder="$t('Choose Domain')"
        :options="domainOptions"
      />
    </b-col>
    <b-col cols="8" class="base-flex-wrap px-0">
      <base-input
        :namespace="`${namespace}.ip`"
        :placeholder="$t('IPv4')"
      />
      <base-input-number
        :namespace="`${namespace}.port`"
        :placeholder="$t('Port')"
      />
      <base-input-number
        :namespace="`${namespace}.pfconnector_port`"
        :placeholder="$t('Connector Port')"

      />
    </b-col>
  </b-row>
</template>
<script>
import {
  BaseInput,
  BaseInputNumber,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputNumber,
  BaseInputChosenOne,
}

import { computed, inject, ref } from '@vue/composition-api'
import { useInputMetaProps } from '@/composables/useMeta'
import { useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = () => {
  const form = inject('form', ref({}))
  const domainOptions = computed(() => (form.value.domains || []).map(domain => ({ text: domain, value: domain })))

  return {
    domainOptions
  }
}

// @vue/component
export default {
  name: 'base-dns',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
