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

    <form-group-eduroam-options namespace="eduroam_options"
      :column-label="$i18n.t('Eduroam Realm Options')"
      :text="$i18n.t('You can add Eduroam FreeRADIUS options in the realm definition.')"
    />

    <form-group-eduroam-radius-auth namespace="eduroam_radius_auth"
      :column-label="$i18n.t('Eduroam RADIUS AUTH')"
      :text="$i18n.t('The RADIUS Server(s) to proxy authentication.')"
    />

    <form-group-eduroam-radius-auth-proxy-type namespace="eduroam_radius_auth_proxy_type"
      :column-label="$i18n.t('Type')"
      :text="$i18n.t('Home server pool type.')"
    />

    <form-group-eduroam-radius-auth-compute-in-pf namespace="eduroam_radius_auth_compute_in_pf"
      :column-label="$i18n.t('Authorize from PacketFence')"
      :text="$i18n.t('Should we forward the request to PacketFence to have a dynamic answer or do we use the remote proxy server answered attributes?')"
    />

    <form-group-auth-listening-port namespace="auth_listening_port"
      :column-label="$i18n.t('Authentication listening port')"
      :text="$i18n.t('PacketFence Eduroam RADIUS virtual server authentication listening port.')"
    />

    <form-group-reject-realm namespace="reject_realm"
      :column-label="$i18n.t('Reject Realms')"
      :text="$i18n.t('Realms that will be rejected.')"
    />

    <form-group-local-realm namespace="local_realm"
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
  FormGroupLocalRealm,
  FormGroupMonitor,
  FormGroupRejectRealm,
  FormGroupEduroamOptions,
  FormGroupEduroamRadiusAuth,
  FormGroupEduroamRadiusAuthProxyType,
  FormGroupEduroamRadiusAuthComputeInPf,
} from './'

const components = {
  BaseForm,

  FormGroupAuthenticationRules,
  FormGroupAuthListeningPort,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupLocalRealm,
  FormGroupMonitor,
  FormGroupRejectRealm,
  FormGroupEduroamOptions,
  FormGroupEduroamRadiusAuth,
  FormGroupEduroamRadiusAuthProxyType,
  FormGroupEduroamRadiusAuthComputeInPf,
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
