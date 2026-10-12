<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>
        <form-group-identifier v-if="!isNew && !isClone"
          namespace="id"
          :column-label="$i18n.t('Identifier')"
          :disabled="!isNew && !isClone"
        />
        <form-group-name namespace="name"
          :column-label="$i18n.t('Name')"
          :disabled="!isNew && !isClone"
        />
        <form-group-module namespace="module"
          :column-label="$i18n.t('PKCS#11 module')"
          :text="$i18n.t('Path of the vendor PKCS#11 library, as seen by the pfpki container (see the conf/pfpki-hsm-volumes file).')"
        />
        <form-group-token-label namespace="token_label"
          :column-label="$i18n.t('Token label')"
          :text="$i18n.t('Label of the token or partition holding the CA keys.')"
        />
        <form-group-pin namespace="pin"
          :column-label="$i18n.t('PIN')"
          :text="(!isNew && !isClone) ? $i18n.t('Leave empty to keep the current PIN.') : undefined"
        />
      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import { BaseForm, BaseFormTab } from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupName,
  FormGroupModule,
  FormGroupTokenLabel,
  FormGroupPin
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupName,
  FormGroupModule,
  FormGroupTokenLabel,
  FormGroupPin
}

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

  return {
    schema
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
