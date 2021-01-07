<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-host namespace="host"
      :column-label="$i18n.t('Hostname')"
      :text="$i18n.t('Server the mysql server is running on.')"
    />

    <form-group-port namespace="port"
      :column-label="$i18n.t('Port')"
      :text="$i18n.t('Port the mysql server is running on.')"
    />

    <form-group-db namespace="db"
      :column-label="$i18n.t('Database name')"
      :text="$i18n.t('Name of the mysql database used by PacketFence.')"
    />

    <form-group-user namespace="user"
      :column-label="$i18n.t('User')"
      :text="$i18n.t('Username of the account with access to the mysql database used by PacketFence.')"
    />

    <form-group-pass namespace="pass"
      :column-label="$i18n.t('Password')"
      :text="$i18n.t('Password for the mysql database used by PacketFence.')"
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
  FormGroupHost,
  FormGroupPort,
  FormGroupDb,
  FormGroupUser,
  FormGroupPass
} from './'

const components = {
  BaseForm,

  FormGroupHost,
  FormGroupPort,
  FormGroupDb,
  FormGroupUser,
  FormGroupPass
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
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

