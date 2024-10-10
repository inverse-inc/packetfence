<template>
  <b-tab :title="$t('Info')">
    <template v-slot:title>
      {{ $i18n.t('Info') }}
    </template>
    <b-row>
      <b-col v-if="node">
        <base-form-group class="text-nowrap" :column-label="$t('Computer Name')">
          {{ node.computername }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Machine Account')">
          {{ node.machine_account }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Realm')">
          {{ node.realm }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Stripped Username')">
          {{ node.stripped_user_name }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Session ID')">
          {{ node.sessionid }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('User Agent')">
          {{ node.user_agent }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('IPv4 Address')" v-if="node.ip4">
          {{ node.ip4.ip }}
            <b-badge variant="success" v-if="node.ip4.active">{{ $t('Since') }} {{ node.ip4.start_time }}</b-badge>
            <b-badge variant="warning" v-else-if="node.ip4.end_time">{{ $t('Inactive since') }} {{ node.ip4.end_time }}</b-badge>
            <b-badge variant="danger" v-else>{{ $t('Inactive') }}</b-badge>
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('IPv6 Address')" v-if="node.ip6">
          {{ node.ip6.ip }}
            <b-badge variant="success" v-if="node.ip6.active">{{ $t('Since') }} {{ node.ip6.start_time }}</b-badge>
            <b-badge variant="warning" v-else-if="node.ip6.end_time">{{ $t('Inactive since') }} {{ node.ip6.end_time }}</b-badge>
            <b-badge variant="danger" v-else>{{ $t('Inactive') }}</b-badge>
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Detect Date')">
          {{ node.detect_date | longDateTime }} <abbr v-if="node.detect_date && node.detect_date !== '0000-00-00 00:00:00'" :title="node.detect_date | longDateTime">(<timeago :datetime="node.detect_date" :auto-update="60" :locale="$i18n.locale"/>)</abbr>
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Registration Date')">
          {{ node.regdate | longDateTime }} <abbr v-if="node.regdate && node.regdate !== '0000-00-00 00:00:00'" :title="node.regdate | longDateTime">(<timeago :datetime="node.regdate" :auto-update="60" :locale="$i18n.locale"/>)</abbr>
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Unregistration Date')">
          {{ node.unregdate | longDateTime }} <abbr v-if="node.unregdate && node.unregdate !== '0000-00-00 00:00:00'" :title="node.unregdate | longDateTime">(<timeago :datetime="node.unregdate" :auto-update="60" :locale="$i18n.locale"/>)</abbr>
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last ARP')">
          {{ node.last_arp | longDateTime }} <abbr v-if="node.last_arp && node.last_arp !== '0000-00-00 00:00:00'" :title="node.last_arp | longDateTime">(<timeago :datetime="node.last_arp" :auto-update="60" :locale="$i18n.locale"/>)</abbr>
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last DHCP')">
          {{ node.last_dhcp | longDateTime }} <abbr v-if="node.last_dhcp && node.last_dhcp !== '0000-00-00 00:00:00'" :title="node.last_dhcp | longDateTime">(<timeago :datetime="node.last_dhcp" :auto-update="60" :locale="$i18n.locale"/>)</abbr>
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last Seen')">
          {{ node.last_seen | longDateTime }} <abbr v-if="node.last_seen && node.last_seen !== '0000-00-00 00:00:00'" :title="node.last_seen | longDateTime">(<timeago :datetime="node.last_seen" :auto-update="60" :locale="$i18n.locale"/>)</abbr>
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last Connection Type')">
          {{ node.last_connection_type }} <span v-if="node.last_connection_sub_type">/</span> {{ node.last_connection_sub_type }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last .1X Username')">
          {{ node.last_dot1x_username }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last SSID')">
          {{ node.last_ssid }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last Start Time')">
          {{ node.last_start_time }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last Start Timestamp')">
          {{ node.last_start_timestamp }}
        </base-form-group>
        <base-form-group class="text-nowrap" :column-label="$t('Last Switch')">
          {{ node.last_switch }} <span v-if="node.last_switch_mac">/</span> {{ node.last_switch_mac }} <span v-if="node.last_port">/</span> {{ node.last_port }}
        </base-form-group>
      </b-col>
    </b-row>
  </b-tab>
</template>
<script>
import {
  BaseFormGroup
} from '@/components/new/'

const components = {
  BaseFormGroup
}

const props = {
  id: {
    type: String
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const { id } = toRefs(props)
  const { root: { $store } = {} } = context

  const node = computed(() => $store.state.$_nodes.nodes[id.value])

  return {
    node
  }
}
// @vue/component
export default {
  name: 'tab-info',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>