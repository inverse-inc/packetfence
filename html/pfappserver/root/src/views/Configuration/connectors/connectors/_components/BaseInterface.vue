<template>
  <b-row class="w-100" align-v="center" no-gutters>
    <b-col cols="4" class="base-flex-wrap pr-1">
      <base-input
        :namespace="`${namespace}.parent`"
        :placeholder="$t('Parent interface (e.g. eth0)')"
      />
    </b-col>
    <b-col cols="3" class="base-flex-wrap pr-1">
      <base-input-number
        :namespace="`${namespace}.vlan`"
        :placeholder="$t('VLAN ID')"
        :min="1"
        :max="4094"
      />
    </b-col>
    <b-col cols="5" class="base-flex-wrap">
      <base-input
        :namespace="`${namespace}.cidr`"
        :placeholder="$t('IP address / prefix (e.g. 10.10.100.1/24)')"
      />
    </b-col>
  </b-row>
</template>
<script>
import {
  BaseInput,
  BaseInputNumber
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputNumber
}

import { useInputMetaProps } from '@/composables/useMeta'
import { useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

// @vue/component
export default {
  name: 'base-interface',
  inheritAttrs: false,
  components,
  props
}
</script>
