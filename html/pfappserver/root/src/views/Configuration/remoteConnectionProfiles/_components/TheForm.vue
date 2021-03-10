<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Profile Name')"
      :text="$i18n.t('A profile id can only contain alphanumeric characters, dashes, period and or underscores.')"
      :disabled="!isNew && !isClone"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Profile Description')"
    />

    <form-group-status v-show="!isDefault"
      namespace="status"
      :column-label="$i18n.t('Enable profile')"
    />

    <form-group-basic-filter v-show="!isDefault"
      :column-label="$i18n.t('Filter')"
    />

    <form-group-advanced-filter v-show="!isDefault"
      namespace="advanced_filter"
      :column-label="$i18n.t('Advanced filter')"
    />

    <form-group-allow-communication-same-role namespace="allow_communication_same_role"
      :column-label="$i18n.t('Allow communication to devices of the same role')"
    />

    <form-group-allow-communication-to-roles namespace="allow_communication_to_roles"
      :column-label="$i18n.t('Allow communication to devices having these roles')"
    />

    <form-group-resolve-hostnames-of-peers namespace="resolve_hostnames_of_peers"
      :column-label="$i18n.t('Resolve hostnames of peers')"
      :text="$i18n.t('Whether or not the wireguard clients should be able to resolve the DNS names of their peers')"
    />

    <form-group-internal-domain-to-resolve namespace="internal_domain_to_resolve"
      :column-label="$i18n.t('Internal domain to resolve')"
      :text="$i18n.t('Domain that will be appended to the peer hostname')"
    />

    <form-group-additional-domains-to-resolve namespace="additional_domains_to_resolve"
      :column-label="$i18n.t('Additional domains to resolve')"
      :text="$i18n.t('List of domains to resolve through PacketFence inside the wireguard network')"
    />

    <form-group-gateway namespace="gateway"
      :column-label="$i18n.t('Gateway')"
      :text="$i18n.t('Whether or not the wireguard clients matching this profile should run in SDP gateway mode')"
    />

    <form-group-routes namespace="routes"
      :column-label="$i18n.t('Routes')"
      :text="$i18n.t(`List of routes to push to the clients matching this profile. Format should be 'CIDR via GATEWAY'. Example: 10.0.0.0/8 via 192.168.69.5`)"
    />

    <form-group-stun-server namespace="stun_server"
      :column-label="$i18n.t('STUN Server')"
    />
  </base-form>
</template>
<script>
import {
  BaseForm
} from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupStatus,
  FormGroupBasicFilter,
  FormGroupAdvancedFilter,
  FormGroupAllowCommunicationSameRole,
  FormGroupAllowCommunicationToRoles,
  FormGroupResolveHostnamesOfPeers,
  FormGroupInternalDomainToResolve,
  FormGroupAdditionalDomainsToResolve,
  FormGroupGateway,
  FormGroupRoutes,
  FormGroupStunServer
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupStatus,
  FormGroupBasicFilter,
  FormGroupAdvancedFilter,
  FormGroupAllowCommunicationSameRole,
  FormGroupAllowCommunicationToRoles,
  FormGroupResolveHostnamesOfPeers,
  FormGroupInternalDomainToResolve,
  FormGroupAdditionalDomainsToResolve,
  FormGroupGateway,
  FormGroupRoutes,
  FormGroupStunServer
}

import { useForm, useFormProps as props } from '../_composables/useForm'

export const setup = (props, context) => useForm(props, context)

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
