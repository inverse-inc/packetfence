<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Name')"
      :disabled="!isNew && !isClone"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-server-address-port :namespaces="['server1_address', 'server1_port']"
      :column-label="$i18n.t('Server 1 address')"
      :text="$i18n.t('Eduroam server 1 address.')"
    />

    <form-group-server-address-port :namespaces="['server2_address', 'server2_port']"
      :column-label="$i18n.t('Server 2 address')"
      :text="$i18n.t('Eduroam server 2 address.')"
    />

    <form-group-radius-secret namespace="radius_secret"
      :column-label="$i18n.t('RADIUS secret')"
      :text="$i18n.t('Eduroam RADIUS secret.')"
    />

    <form-group-auth-listening-port namespace="auth_listening_port"
      :column-label="$i18n.t('Authentication listening port')"
      :text="$i18n.t('PacketFence Eduroam RADIUS virtual server authentication listening port.')"
    />

    <form-group-reject-realms namespace="reject_realm"
      :column-label="$i18n.t('Reject Realms')"
      :text="$i18n.t('Realms that will be rejected.')"
    />

    <form-group-local-realms namespace="local_realm"
      :column-label="$i18n.t('Local Realms')"
      :text="$i18n.t('Realms that will be authenticate locally.')"
    />

    <form-group-monitor namespace="monitor"
      :column-label="$i18n.t('Monitor')"
      :text="$i18n.t('Do you want to monitor this source?')"
    />

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAuthenticationRules,
  FormGroupAuthListeningPort,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupLocalRealms,
  FormGroupMonitor,
  FormGroupRadiusSecret,
  FormGroupRejectRealms,
  FormGroupServerAddressPort,
} from './'

const components = {
  BaseForm,

  FormGroupAuthenticationRules,
  FormGroupAuthListeningPort,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupLocalRealms,
  FormGroupMonitor,
  FormGroupRadiusSecret,
  FormGroupRejectRealms,
  FormGroupServerAddressPort,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-eduroam',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
