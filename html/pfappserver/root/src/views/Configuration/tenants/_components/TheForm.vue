<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier v-if="!isNew && !isClone"
      namespace="id"
      :column-label="$i18n.t('Indentifier')"
      disabled
    />

    <form-group-name namespace="name"
      :column-label="$i18n.t('Name')"
    />

    <form-group-domain-name namespace="domain_name"
      :column-label="$i18n.t('Domain name')"
    />

    <form-group-portal-domain-name namespace="portal_domain_name"
      :column-label="$i18n.t('Portal domain name')"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupName,
  FormGroupDomainName,
  FormGroupPortalDomainName
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupName,
  FormGroupDomainName,
  FormGroupPortalDomainName
}

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  meta: {
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
