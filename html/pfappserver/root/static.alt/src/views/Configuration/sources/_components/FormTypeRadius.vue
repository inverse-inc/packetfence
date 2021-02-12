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

    <form-group-host namespace="host"
      :column-label="$i18n.t('Host')"
    />

    <form-group-port namespace="port"
      :column-label="$i18n.t('Port')"
      :text="$i18n.t('If you use this source in the realm configuration the accounting port will be this port + 1.')"
    />

    <form-group-secret namespace="secret"
      :column-label="$i18n.t('Secret')"
    />

    <form-group-timeout namespace="timeout"
      :column-label="$i18n.t('Timeout')"
    />

    <form-group-monitor namespace="monitor"
      :column-label="$i18n.t('Monitor')"
      :text="$i18n.t('Do you want to monitor this source?')"
    />

    <form-group-options namespace="options"
      :column-label="$i18n.t('Options')"
      :text="$i18n.t('Define options for FreeRADIUS home_server definition (if you use the source in the realm configuration). Need a radiusd restart.')"
    />

    <form-group-realms namespace="realms"
      :column-label="$i18n.t('Associated Realms')"
      :text="$i18n.t('Realms that will be associated with this source (for the portal/admin GUI/RADIUS post-auth, not for FreeRADIUS proxy).')"
    />

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
    />

    <form-group-administration-rules namespace="administration_rules"
      :column-label="$i18n.t('Administration Rules')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupMonitor,
  FormGroupOptions,
  FormGroupPort,
  FormGroupRealms,
  FormGroupSecret,
  FormGroupTimeout,
} from './'

const components = {
  BaseForm,

  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupMonitor,
  FormGroupOptions,
  FormGroupPort,
  FormGroupRealms,
  FormGroupSecret,
  FormGroupTimeout,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-radius',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
