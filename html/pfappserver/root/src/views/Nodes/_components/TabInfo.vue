<template>
  <b-tab :title="$t('Info')">
    <template v-slot:title>
      {{ $i18n.t('Info') }}
    </template>
    <b-row>
      <b-col v-if="node">
        <pf-form-row class="text-nowrap" :column-label="$t('Computer Name')">
          {{ node.computername }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Machine Account')">
          {{ node.machine_account }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Realm')">
          {{ node.realm }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Stripped Username')">
          {{ node.stripped_user_name }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Session ID')">
          {{ node.sessionid }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('User Agent')">
          {{ node.user_agent }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('IPv4 Address')" v-if="node.ip4">
          {{ node.ip4.ip }}
            <b-badge variant="success" v-if="node.ip4.active">{{ $t('Since') }} {{ node.ip4.start_time }}</b-badge>
            <b-badge variant="warning" v-else-if="node.ip4.end_time">{{ $t('Inactive since') }} {{ node.ip4.end_time }}</b-badge>
            <b-badge variant="danger" v-else>{{ $t('Inactive') }}</b-badge>
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('IPv6 Address')" v-if="node.ip6">
          {{ node.ip6.ip }}
            <b-badge variant="success" v-if="node.ip6.active">{{ $t('Since') }} {{ node.ip6.start_time }}</b-badge>
            <b-badge variant="warning" v-else-if="node.ip6.end_time">{{ $t('Inactive since') }} {{ node.ip6.end_time }}</b-badge>
            <b-badge variant="danger" v-else>{{ $t('Inactive') }}</b-badge>
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Detect Date')">
          <abbr :title="node.detect_date | longDateTime"><timeago :datetime="node.detect_date" :auto-update="60" :locale="$i18n.locale"></timeago></abbr>
          <!-- <span class="ml-1" v-b-tooltip.hover :title="node.detect_date | longDateTime"><icon name="regular/question-circle"></icon></span> -->
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Registration Date')">
          {{ node.regdate | longDateTime }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Unregistration Date')">
          {{ node.unregdate | longDateTime }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last ARP')">
          {{ node.last_arp | longDateTime }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last DHCP')">
          {{ node.last_dhcp | longDateTime }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last Seen')">
          {{ node.last_seen | longDateTime }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last Skip')">
          {{ node.lastskip | longDateTime }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last Connection Type')">
          {{ node.last_connection_type }} <span v-if="node.last_connection_sub_type">/</span> {{ node.last_connection_sub_type }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last .1X Username')">
          {{ node.last_dot1x_username }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last SSID')">
          {{ node.last_ssid }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last Start Time')">
          {{ node.last_start_time }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last Start Timestamp')">
          {{ node.last_start_timestamp }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Last Switch')">
          {{ node.last_switch }} <span v-if="node.last_switch_mac">/</span> {{ node.last_switch_mac }} <span v-if="node.last_port">/</span> {{ node.last_port }}
        </pf-form-row>
      </b-col>
    </b-row>
  </b-tab>      
</template>
<script>
import pfFormRow from '@/components/pfFormRow'

const components = {
  pfFormRow
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