<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <b-input-group>

      <b-row class="w-100 mx-0 mb-1 px-0" align-v="center" no-gutters>
        <b-col sm="8" align-self="start">

          <base-input
            :namespace="namespaces[0]"
            :placeholder="$i18n.t('Address')"
          />

        </b-col>
        <b-col sm="4" align-self="start" class="pl-1">

          <base-input-number
            :namespace="namespaces[1]"
            :placeholder="$i18n.t('Port')"
          />

        </b-col>
      </b-row>

    </b-input-group>
    <template v-slot:description v-if="text">
      <div v-html="text"/>
    </template>
  </b-form-group>
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

import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInputMetaProps } from '@/composables/useMeta'
import { useInputProps } from '@/composables/useInput'

const props = {
  ...useFormGroupProps,
  ...useInputMetaProps,
  ...useInputProps,

  namespaces: {
    type: Array,
    default: () => (['address', 'port']),
    validator: value => value.length === 2
  }
}

// @vue/component
export default {
  name: 'base-form-group-server-address-port',
  inheritAttrs: false,
  components,
  props
}
</script>
