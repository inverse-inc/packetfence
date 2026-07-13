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

    <form-group-client-identifier namespace="client_id"
      :column-label="$i18n.t('Client ID')"
    />

    <form-group-client-secret namespace="client_secret"
      :column-label="$i18n.t('Client Secret')"
    />

    <form-group-tenant-identifier namespace="tenant_id"
      :column-label="$i18n.t('Tenant ID')"
    />

    <form-group-graph-url namespace="graph_url"
      :column-label="$i18n.t('Graph Url')"
      :text="$i18n.t('What is the Graph API Url.')"
    />

    <form-group-oauth-url namespace="oauth_url"
      :column-label="$i18n.t('OAuth Url')"
      :text="$i18n.t('What is the OAuth API Url to get the oauth token.')"
    />

    <form-group-user-groups-url-path namespace="user_groups_url_path"
      :column-label="$i18n.t('User Groups Url Path')"
      :text="$i18n.t(`Path appended to the Graph Url to lookup group memberships. %USERNAME is replaced with the URI-escaped username. Use /v1.0/devices(deviceId='%USERNAME')/memberOf to look up device/machine group memberships instead of user groups.`)"
    />

    <form-group-lookup-device-owner namespace="lookup_device_owner"
      :column-label="$i18n.t('Lookup Device Owner')"
      :text="$i18n.t(`When enabled and looking up device/machine groups, also resolve the device's registered owner in Entra and merge that owner's groups into the memberOf used for rule matching. Only the first registered owner is used.`)"
    />

    <form-group-device-owner-url-path namespace="device_owner_url_path"
      :column-label="$i18n.t('Device Owner Url Path')"
      :text="$i18n.t(`Path appended to the Graph Url to resolve the device's registered owner. %USERNAME is replaced with the URI-escaped device identity. Only used when 'Lookup Device Owner' is enabled.`)"
    />

    <form-group-owner-groups-url-path namespace="owner_groups_url_path"
      :column-label="$i18n.t('Owner Groups Url Path')"
      :text="$i18n.t(`Path appended to the Graph Url to look up the resolved owner's group memberships. %USERNAME is replaced with the URI-escaped owner id. Only used when 'Lookup Device Owner' is enabled.`)"
    />

    <form-group-timeout namespace="timeout"
      :column-label="$i18n.t('Timeout')"
      :text="$i18n.t('Timeout while sending HTTP requests to Azure AD.')"
    />

    <form-group-realms namespace="realms"
      :column-label="$i18n.t('Associated Realms')"
      :text="$i18n.t('Realms that will be associated with this source.')"
    />

    <form-group-user-groups-cache namespace="user_groups_cache"
      :column-label="$i18n.t('User Groups Cache')"
      :text="$i18n.t('How much time in seconds should the groups of the user be cached. A value of 0 disables the cache.')"
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
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupDescription,
  FormGroupDeviceOwnerUrlPath,
  FormGroupGraphUrl,
  FormGroupIdentifier,
  FormGroupLookupDeviceOwner,
  FormGroupOauthUrl,
  FormGroupOwnerGroupsUrlPath,
  FormGroupRealms,
  FormGroupTenantIdentifier,
  FormGroupTimeout,
  FormGroupUserGroupsCache,
  FormGroupUserGroupsUrlPath,
} from './'

const components = {
  BaseForm,

  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupDescription,
  FormGroupDeviceOwnerUrlPath,
  FormGroupGraphUrl,
  FormGroupIdentifier,
  FormGroupLookupDeviceOwner,
  FormGroupOauthUrl,
  FormGroupOwnerGroupsUrlPath,
  FormGroupRealms,
  FormGroupTenantIdentifier,
  FormGroupTimeout,
  FormGroupUserGroupsCache,
  FormGroupUserGroupsUrlPath,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-azure-ad',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
