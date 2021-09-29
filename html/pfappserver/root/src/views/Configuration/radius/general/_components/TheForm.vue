<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-record-accounting-in-sql namespace="record_accounting_in_sql"
      :column-label="$i18n.t('Record accounting in SQL tables')"
      :text="$i18n.t('Record the accounting data in the SQL tables. Requires a restart of radiusd to be effective.')"
    />

    <form-group-filter-in-packetfence-authorize namespace="filter_in_packetfence_authorize"
      :column-label="$i18n.t('Use RADIUS filters in packetfence authorize')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.authorize section. Requires a restart of radiusd to be effective.')"
    />

    <form-group-filter-in-packetfence-pre-proxy namespace="filter_in_packetfence_pre_proxy"
      :column-label="$i18n.t('Use RADIUS filters in packetfence pre_proxy')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.pre_proxy section. Requires a restart of radiusd to be effective.')"
    />

    <form-group-filter-in-packetfence-post-proxy namespace="filter_in_packetfence_post_proxy"
      :column-label="$i18n.t('Use RADIUS filters in packetfence post_proxy')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.post_proxy section. Requires a restart of radiusd to be effective.')"
    />
    <form-group-filter-in-packetfence-preacct namespace="filter_in_packetfence_preacct"
      :column-label="$i18n.t('Use RADIUS filters in packetfence preacct')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.preacct section. Requires a restart of radiusd to be effective.')"
    />

    <form-group-filter-in-packetfence-accounting namespace="filter_in_packetfence_accounting"
      :column-label="$i18n.t('Use RADIUS filters in packetfence accounting')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.accounting section. Requires a restart of radiusd to be effective.')"
    />
    <form-group-filter-in-packetfence-tunnel-authorize namespace="filter_in_packetfence-tunnel_authorize"
      :column-label="$i18n.t('Use RADIUS filters in packetfence-tunnel authorize')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence-tunnel.authorize section. Requires a restart of radiusd to be effective.')"
    />

    <form-group-filter-in-eduroam-authorize namespace="filter_in_eduroam_authorize"
      :column-label="$i18n.t('Use RADIUS filters in eduroam authorize')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS eduroam.authorize section. Requires a restart of radiusd to be effective.')"
    />
    <form-group-filter-in-eduroam-pre-proxy namespace="filter_in_eduroam_pre_proxy"
      :column-label="$i18n.t('Use RADIUS filters in eduroam pre_proxy')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS eduroam.pre_proxy section. Requires a restart of radiusd to be effective.')"
    />

    <form-group-filter-in-eduroam-post-proxy namespace="filter_in_eduroam_post_proxy"
      :column-label="$i18n.t('Use RADIUS filters in eduroam post_proxy')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS eduroam.post_proxy section. Requires a restart of radiusd to be effective.')"
    />

    <form-group-filter-in-eduroam-preacct namespace="filter_in_eduroam_preacct"
      :column-label="$i18n.t('Use RADIUS filters in eduroam preacct')"
      :text="$i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS eduroam.preacct section. Requires a restart of radiusd to be effective.')"
    />

    <form-group-ntlm-redis-cache namespace="ntlm_redis_cache"
      :column-label="$i18n.t('NTLM Redis cache')"
      :text="$i18n.t('Enables a Redis driven cache for NTLM authentication.In order for this to work, you need to setup proper NT hash syncronization between your PacketFence server and your AD. Refer to the Administration guide for more details. Applying this requires a restart of radiusd.')"
    />

    <form-group-radius-attributes namespace="radius_attributes"
      :column-label="$i18n.t('RADIUS attributes')"
      :text="$i18n.t('List of RADIUS attributes that can be used in the sources configuration.')"
    />
    <b-row v-if="impliedRadiusAtttributes.length">
      <b-col cols="3"></b-col>
      <b-col cols="9">
        <div class="alert alert-info mr-3">
          <p><strong>{{ $i18n.t('Built-in RADIUS Attributes:') }}</strong></p>
          <span v-for="radiusAttribute in impliedRadiusAtttributes" :key="radiusAttribute"
            class="badge badge-info mr-1">{{ radiusAttribute }}</span>
        </div>
      </b-col>
    </b-row>

    <form-group-normalize-radius-machine-auth-username namespace="normalize_radius_machine_auth_username"
      :column-label="$i18n.t('RADIUS machine auth with username')"
      :text="$i18n.t('Use the RADIUS username instead of the TLS certificate common name when doing machine authentication.')"
    />

    <form-group-username-attributes namespace="username_attributes"
      :column-label="$i18n.t('Username attributes')"
      :text="$i18n.t('Which attributes to use to get the username from a RADIUS request. The order of the attributes are listed in this configuration parameter is followed while performing the lookup.')"
    />
  </base-form>
</template>
<script>
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupRecordAccountingInSql,
  FormGroupFilterInPacketfenceAuthorize,
  FormGroupFilterInPacketfencePreProxy,
  FormGroupFilterInPacketfencePostProxy,
  FormGroupFilterInPacketfencePreacct,
  FormGroupFilterInPacketfenceAccounting,
  FormGroupFilterInPacketfenceTunnelAuthorize,
  FormGroupFilterInEduroamAuthorize,
  FormGroupFilterInEduroamPreProxy,
  FormGroupFilterInEduroamPostProxy,
  FormGroupFilterInEduroamPreacct,
  FormGroupNtlmRedisCache,
  FormGroupRadiusAttributes,
  FormGroupNormalizeRadiusMachineAuthUsername,
  FormGroupUsernameAttributes
} from './'

const components = {
  BaseForm,

  FormGroupRecordAccountingInSql,
  FormGroupFilterInPacketfenceAuthorize,
  FormGroupFilterInPacketfencePreProxy,
  FormGroupFilterInPacketfencePostProxy,
  FormGroupFilterInPacketfencePreacct,
  FormGroupFilterInPacketfenceAccounting,
  FormGroupFilterInPacketfenceTunnelAuthorize,
  FormGroupFilterInEduroamAuthorize,
  FormGroupFilterInEduroamPreProxy,
  FormGroupFilterInEduroamPostProxy,
  FormGroupFilterInEduroamPreacct,
  FormGroupNtlmRedisCache,
  FormGroupRadiusAttributes,
  FormGroupNormalizeRadiusMachineAuthUsername,
  FormGroupUsernameAttributes
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

import { computed, toRefs } from '@vue/composition-api'
import { useNamespaceMetaImplied } from '@/composables/useMeta'

export const setup = (props) => {

  const {
    meta
  } = toRefs(props)

  const impliedRadiusAtttributes = computed(() => {
    const csv = useNamespaceMetaImplied('radius_attributes', meta)
    return (csv) ? csv.split(',') : []
  })

  const schema = computed(() => schemaFn(props))

  return {
    schema,
    impliedRadiusAtttributes
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

