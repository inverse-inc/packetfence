<template>
  <base-form
    :form="form"
    :schema="schema"
    :is-loading="isLoading">
    <base-form-tab title="Edit" active>
      <template v-slot:title>
        {{ $i18n.t('Edit') }}
      </template>
      <b-row>
        <b-col>
          <!-- TODO: handle complex lookup -->
          <form-group-pid namespace="pid"
            :column-label="$i18n.t('Owner')"
            placeholder="default"
          />
          <form-group-status namespace="status"
            :column-label="$i18n.t('Status')"
            internal-search="false"
            :options="statuses"
          />
          <form-group-role namespace="category_id"
            :column-label="$i18n.t('Role')"
            internal-search="false"
            :options="rolesWithNull"
          />
          <pf-form-datetime :column-label="$t('Unregistration')"
            :form-store-name="formStoreName" form-namespace="unregdate"
            :moments="['1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
          />
          <!-- <form-group-unregdate namespace="unregdate"
            :column-label="$i18n.t('Unregistration')"
          /> -->
          <form-group-time-balance namespace="time_balance"
            :column-label="$i18n.t('Access Time Balance')"
            :text="$i18n.t('Seconds')"
          />
          <form-group-bandwidth-balance namespace="bandwidth_balance"
            :column-label="$i18n.t('Bandwidth Balance')"
            :max="sqlLimits.ubigint.max"
          />
          <form-group-voip namespace="voip"
            :column-label="$i18n.t('Voice Over IP')"
          />
          <form-group-bypass-vlan namespace="bypass_vlan"
            :column-label="$i18n.t('Bypass VLAN')"
          />
          <form-group-bypass-role namespace="bypass_role_id"
            :column-label="$i18n.t('Bypass Role')"
            internal-search="false"
            :options="rolesWithNull"
          />
          <form-group-notes namespace="notes"
            :column-label="$i18n.t('Notes')"
          />
        </b-col>
      </b-row>
    </base-form-tab>

    <base-form-tab title="Info">
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
    </base-form-tab>

    <base-form-tab title="Fingerbank">
      <b-row>
        <b-col v-if="node">
          <pf-form-row class="text-nowrap" :column-label="$t('Device Class')">
            {{ node.device_class }}
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('Device Manufacturer')">
            {{ node.device_manufacturer }}
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('Device Type')">
            {{ node.device_type }}
          </pf-form-row>
          <pf-form-row :column-label="$t('Fully Qualified Device Name')">
            {{ node.fingerbank.device_fq }}
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('Version')">
            {{ node.fingerbank.version }}
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('Score')" v-if="node.fingerbank.score">
            <pf-fingerbank-score class="col-12 col-md-6 col-lg-3" :score="node.fingerbank.score"></pf-fingerbank-score>
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('Mobile')">
            <div v-if="node.fingerbank.mobile === 1">
              <icon class="mr-1" name="check-square"></icon> {{ $t('Yes') }}
            </div>
            <div v-else-if="node.fingerbank.mobile === 0">
              <icon class="mr-1" name="regular/square"></icon> {{ $t('No') }}
            </div>
            <div v-else class="text-muted">
              {{ $t('Unknown') }}
            </div>
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('DHCP Fingerprint')">
            {{ node.dhcp_fingerprint }}
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('DHCP Vendor')">
            {{ node.dhcp_vendor }}
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('DHCPv6 Fingerprint')">
            {{ node.dhcp6_fingerprint }}
          </pf-form-row>
          <pf-form-row class="text-nowrap" :column-label="$t('DHCPv6 Enterprise')">
            {{ node.dhcp6_enterprise }}
          </pf-form-row>
        </b-col>
      </b-row>
    </base-form-tab>

    <base-form-tab title="Timeline">
      <template v-slot:title>
        {{ $i18n.t('Timeline') }}
      </template>
      <b-row>
        <b-col>
          <timeline
            ref="timelineRef"
            :items="visItems"
            :groups="visGroups"
            :options="visOptions"
          ></timeline>
        </b-col>
      </b-row>
    </base-form-tab>

    <base-form-tab title="IPv4 Addresses">
      <template v-slot:title>
        {{ $t('IPv4') }} <b-badge pill v-if="node && node.ip4 && node.ip4.history && node.ip4.history.length > 0" variant="light" class="ml-1">{{ node.ip4.history.length }}</b-badge>
      </template>
      <b-table v-if="node && node.ip4"
        :items="node.ip4.history" :fields="ipLogFields" :sort-by="iplogSortBy" :sort-desc="iplogSortDesc" responsive show-empty sort-icon-left striped>
        <template v-slot:empty>
          <pf-empty-table :is-loading="isLoading" text="">{{ $t('No IPv4 addresses found') }}</pf-empty-table>
        </template>
      </b-table>
    </base-form-tab>

    <base-form-tab title="IPv6 Addresses">
      <template v-slot:title>
        {{ $t('IPv6') }} <b-badge pill v-if="node && node.ip6 && node.ip6.history && node.ip6.history.length > 0" variant="light" class="ml-1">{{ node.ip6.history.length }}</b-badge>
      </template>
      <b-table v-if="node && node.ip6"
        :items="node.ip6.history" :fields="ipLogFields" :sort-by="iplogSortBy" :sort-desc="iplogSortDesc" responsive show-empty sort-icon-left striped>
        <template v-slot:empty>
          <pf-empty-table :is-loading="isLoading" text="">{{ $t('No IPv6 addresses found') }}</pf-empty-table>
        </template>
      </b-table>
    </base-form-tab>

    <base-form-tab title="Location">
      <template v-slot:title>
        {{ $t('Location') }} <b-badge pill v-if="node && node.locations && node.locations.length > 0" variant="light" class="ml-1">{{ node.locations.length }}</b-badge>
      </template>
      <b-table v-if="node"
        :items="node.locations" :fields="locationLogFields" :sort-by="locationSortBy" :sort-desc="locationSortDesc" responsive show-empty sort-icon-left striped>
          <template v-slot:cell(switch)="location">
            <b-button variant="link" :to="{ name: 'switch', params: { id: location.item.switch_ip } }">{{ location.item.switch_ip }}</b-button> / <mac>{{ location.item.switch_mac }}</mac><br/>
            <b-badge class="mr-1" v-if="location.item.port">{{ $t('Port') }}: {{ location.item.port }} <span v-if="location.item.ifDesc">({{ location.item.ifDesc }})</span></b-badge>
            <b-badge class="mr-1" v-if="location.item.ssid"><icon name="wifi" class="align-baseline" scale=".6"></icon> {{ location.item.ssid }}</b-badge>
            <b-badge class="mr-1">{{ $t('Role') }}: {{ location.item.role }}</b-badge>
            <b-badge>{{ $t('VLAN') }}: {{ location.item.vlan }}</b-badge>
          </template>
          <template v-slot:cell(connection_type)="location">
            {{ location.item.connection_type }} {{ connectionSubType(location.item.connection_sub_type) }}
          </template>
          <template v-slot:empty>
            <pf-empty-table :is-loading="isLoading" text="">{{ $t('No location logs found') }}</pf-empty-table>
          </template>
        </b-table>
    </base-form-tab>

    <base-form-tab title="SecurityEvents">
      <template v-slot:title>
        {{ $t('Security Events') }} <b-badge pill v-if="node && node.security_events && node.security_events.length > 0" variant="light" class="ml-1">{{ node.security_events.length }}</b-badge>
      </template>
      <b-table v-if="node"
        :items="node.security_events" :fields="securityEventFields" :sortBy="securityEventSortBy" :sortDesc="securityEventSortDesc" responsive show-empty sort-icon-left striped>
        <template v-slot:cell(description)="security_event">
          <icon v-if="!securityEventDescription(security_event.item.security_event_id)" name="circle-notch" spin></icon>
          <router-link v-else :to="{ path: `/configuration/security_event/${security_event.item.security_event_id}` }">{{ securityEventDescription(security_event.item.security_event_id) }}</router-link>
        </template>
        <template v-slot:cell(status)="security_event">
          <b-badge pill variant="success" v-if="security_event.item.status === 'open'">{{ $t('open') }}</b-badge>
          <b-badge pill variant="danger" v-else-if="security_event.item.status === 'closed'">{{ $t('closed') }}</b-badge>
          <b-badge pill variant="secondary" v-else>{{ $t('unknown') }}</b-badge>
        </template>
        <template v-slot:cell(buttons)="security_event">
          <b-button v-if="security_event.item.status === 'open'" size="sm" variant="outline-secondary" @click="onRelease(security_event.item.id)">{{ $t('Release') }}</b-button>
        </template>
        <template v-slot:empty>
          <pf-empty-table :is-loading="isLoading" text="">{{ $t('No security events found') }}</pf-empty-table>
        </template>
      </b-table>
    </base-form-tab>

    <!-- TODO
    <b-tab title="WMI Rules">
      <template v-slot:title>
        {{ $t('WMI Rules') }}
      </template>
    </b-tab>
    -->

    <base-form-tab title="Option82">
      <template v-slot:title>
        {{ $t('Option82') }} <b-badge pill v-if="node && node.dhcpoption82 && node.dhcpoption82.length > 0" variant="light" class="ml-1">{{ node.dhcpoption82.length }}</b-badge>
      </template>
      <b-table v-if="node && node.dhcpoption82"
        :items="node.dhcpoption82" :fields="dhcpOption82Fields" :sortBy="dhcpOption82SortBy" :sortDesc="dhcpOption82SortDesc" responsive show-empty sort-icon-left striped>
        <template v-slot:empty>
          <pf-empty-table :is-loading="isLoading" text="">{{ $t('No DHCP option82 logs found') }}</pf-empty-table>
        </template>
      </b-table>
    </base-form-tab>

  </base-form>
</template>

<script>
import { computed, onBeforeUnmount, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { DataSet, Timeline } from 'vue2vis'
import {
  BaseForm,
  BaseFormGroupInput,
  BaseFormTab
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFingerbankScore from '@/components/pfFingerbankScore'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormRow from '@/components/pfFormRow'
import { mysqlLimits as sqlLimits } from '@/globals/mysqlLimits'
import { pfEapType as eapType } from '@/globals/pfEapType'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'

import {
  FormGroupPid,
  FormGroupStatus,
  FormGroupRole,
  FormGroupUnregdate,
  FormGroupTimeBalance,
  FormGroupBandwidthBalance,
  FormGroupVoip,
  FormGroupBypassVlan,
  FormGroupBypassRole,
  FormGroupNotes,
} from './'

import {
//   updateValidators,
  ipLogFields,
  locationLogFields,
  securityEventFields,
  dhcpOption82Fields
} from '../_config/'

const components = {
  BaseForm,
  BaseFormGroupInput,
  BaseFormTab,

  FormGroupPid,
  FormGroupStatus,
  FormGroupRole,
  FormGroupUnregdate,
  FormGroupTimeBalance,
  FormGroupBandwidthBalance,
  FormGroupVoip,
  FormGroupBypassVlan,
  FormGroupBypassRole,
  FormGroupNotes,

  Timeline,
  pfEmptyTable,
  pfFingerbankScore,
  pfFormDatetime,
  pfFormRow
}

const props = {
  id: { // from router
    type: String,
    default: null
  },
  form: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

const setup = (props, context) => {

  const { id, form } = toRefs(props)
  const { root: { $store } = {} } = context

  if (acl.$can('read', 'security_events')) {
    $store.dispatch('config/getSecurityEvents')
  }
  $store.dispatch('session/getAllowedNodeRoles')

  const iplogSortBy = ref('end_time')
  const iplogSortDesc =  ref(false)

  const locationSortBy = ref('start_time')
  const locationSortDesc = ref(true)

  const securityEventSortBy = ref('start_date')
  const securityEventSortDesc = ref(true)

  const dhcpOption82SortBy = ref('created_at')
  const dhcpOption82SortDesc = ref(true)

  const triggerSecurityEvent = ref(null)
  const timelineRef = ref(null)

  const visGroups = new DataSet()
  const visItems = new DataSet()
  const visOptions = ref({
    editable: false,
    margin: {
      item: 25
    },
    orientation: {
      axis: 'both',
      item: 'bottom'
    },
    selectable: false,
    stack: true,
    tooltip: {
      followMouse: true
    }
  })

  const node = computed(() => $store.state.$_nodes.nodes[id.value])
  const rolesWithNull = computed(() => {
    return [
      { value: null, text: i18n.t('No Role') }, // prepend a null value to roles
      ...$store.getters['session/allowedNodeRolesList']
    ]
  })
  const securityEvents = computed(() => $store.getters['config/sortedSecurityEvents'])
  const statuses = computed(() => conditionValues[conditionType.NODE_STATUS])
  const escapeKey = computed(() => $store.getters['events/escapeKey'])

  const onRelease = (security_event_id) => $store.dispatch('$_nodes/clearSecurityEventNode', { security_event_id, mac: id.value })
  const connectionSubType = (type) => {
    if (type && eapType[type]) {
      return eapType[type]
    }
  }
  const securityEventDescription = (id) => {
    const { state: { config: { securityEvents: { [id]: { desc = '' } = {} } = {} } = {} } = {} } = $store
    return desc
  }
  const setupVis = () => {
    const node = $store.state.$_nodes.nodes[id.value]
    if (node) {
      if (node.detect_date && node.detect_date !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-seen`,
          content: i18n.t('Seen')
        })
        addVisItem({
          id: 'detect',
          group: `${id.value}-seen`,
          start: new Date(node.detect_date),
          end: (node.last_seen && node.last_seen !== '0000-00-00 00:00:00' && node.last_seen !== node.detect_date) ? new Date(node.last_seen) : null,
          content: i18n.t('Detected')
        })
      } else if (node.last_seen && node.last_seen !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-seen`,
          content: i18n.t('Seen')
        })
        addVisItem({
          id: 'last_seen',
          group: `${id.value}-seen`,
          start: new Date(node.last_seen),
          content: i18n.t('Last Seen')
        })
      }
      if (node.regdate && node.regdate !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-registered`,
          content: i18n.t('Registered')
        })
        addVisItem({
          id: 'regdate',
          group: `${id.value}-registered`,
          start: new Date(node.regdate),
          end: (node.unregdate && node.unregdate !== '0000-00-00 00:00:00' && node.unregdate !== node.regdate) ? new Date(node.unregdate) : null,
          content: i18n.t('Registered')
        })
      }
      if (node.last_arp && node.last_arp !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-general`,
          content: i18n.t('General')
        })
        addVisItem({
          id: 'last_arp',
          group: `${id.value}-general`,
          start: new Date(node.last_arp),
          content: i18n.t('Last ARP')
        })
      }
      if (node.last_dhcp && node.last_dhcp !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-general`,
          content: i18n.t('General')
        })
        addVisItem({
          id: 'last_dhcp',
          group: `${id.value}-general`,
          start: new Date(node.last_dhcp),
          content: i18n.t('Last DHCP')
        })
      }
      if (node.lastskip && node.lastskip !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-general`,
          content: i18n.t('General')
        })
        addVisItem({
          id: 'lastskip',
          group: `${id.value}-general`,
          start: new Date(node.lastskip),
          content: i18n.t('Last Skip')
        })
      }
      try {
        node.ip4.history.forEach(function (ip4) {
          addVisGroup({
            id: `${id.value}-ipv4`,
            content: i18n.t('IPv4 Addresses')
          })
          addVisItem({
            id: `ipv4-${ip4.ip}`,
            group: `${id.value}-ipv4`,
            start: new Date(ip4.start_time),
            end: (ip4.end_time !== '0000-00-00 00:00:00' && ip4.end_time !== ip4.start_time) ? new Date(ip4.end_time) : null,
            content: ip4.ip
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.ip6.history.forEach(function (ip6) {
          addVisGroup({
            id: `${id.value}-ipv6`,
            content: i18n.t('IPv6 Addresses')
          })
          addVisItem({
            id: `ipv6-${ip6.ip}`,
            group: `${id.value}-ipv6`,
            start: new Date(ip6.start_time),
            end: (ip6.end_time !== '0000-00-00 00:00:00' && ip6.end_time !== ip6.start_time) ? new Date(ip6.end_time) : null,
            content: ip6.ip
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.locations.forEach(function (location) {
          addVisGroup({
            id: `${id.value}-location`,
            content: i18n.t('Locations')
          })
          addVisItem({
            id: `location-${location.id}`,
            group: `${id.value}-location`,
            start: new Date(location.start_time),
            end: (location.end_time && location.end_time !== '0000-00-00 00:00:00' && location.end_time !== location.start_time) ? new Date(location.end_time) : null,
            content: `${location.ssid}/${i18n.t('Role')}:${location.role}/VLAN:${location.vlan}`
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.security_events.forEach(function (securityEvent) {
          addVisGroup({
            id: `${id.value}-security_event`,
            content: i18n.t('Security Events')
          })
          addVisItem({
            id: `security_event-${securityEvent.security_event_id}`,
            group: `${id.value}-security_event`,
            start: new Date(securityEvent.start_date),
            end: (securityEvent.release_date !== '0000-00-00 00:00:00' && securityEvent.release_date !== securityEvent.start_date) ? new Date(securityEvent.release_date) : null,
            content: securityEventDescription(securityEvent.security_event_id)
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.dhcpoption82.forEach(function (dhcpoption82) {
          addVisGroup({
            id: `${id.value}-dhcpoption82`,
            content: i18n.t('DHCP Option 82')
          })
          addVisItem({
            id: `dhcpoption82-${dhcpoption82.created_at}`,
            group: `${id.value}-dhcpoption82`,
            start: new Date(dhcpoption82.created_at),
            content: ((dhcpoption82.switch_id) ? (`${dhcpoption82.switch_id}/`) : '') + ((dhcpoption82.port) ? `${i18n.t('Port')}:${dhcpoption82.port}/` : '') + `VLAN:${dhcpoption82.vlan}`
          })
        })
      } catch (e) {
        // noop
      }
    }
  }
  const addVisGroup = (group) => {
    if (!visGroups.getIds().includes(group.id)) {
      visGroups.add([group])
    }
  }
  const addVisItem = (item) => {
    if (!visItems.getIds().includes(item.id)) {
      if (!item.title) {
        item.title = item.content
      }
      visItems.add([item])
    }
  }
  let timeoutVis = null
  const redrawVis = () => {
    // buffer async calls to redraw
    if (timeoutVis) clearTimeout(timeoutVis)
    timeoutVis = setTimeout(() => {
      setupVis()
      if (timelineRef.value)
        timelineRef.redraw()
    }, 100)
  }
  // const searchUsers = () => {
  //   let body = {
  //     limit: 10,
  //     fields: ['pid', 'firstname', 'lastname', 'email'],
  //     sort: ['pid'],
  //     query: {
  //       op: 'and',
  //       values: [{
  //         op: 'or',
  //         values: [
  //           { field: 'pid', op: 'contains', value: form.pid },
  //           { field: 'firstname', op: 'contains', value: form.pid },
  //           { field: 'lastname', op: 'contains', value: form.pid },
  //           { field: 'email', op: 'contains', value: form.pid }
  //         ]
  //       }]
  //     }
  //   }
  //   usersApi.search(body).then((data) => {
  //     matchingUsers.value = data.items.map(item => item.pid)
  //   })
  // }

  watch(node, () => redrawVis(), { deep: true })
  watch(securityEvents, (a, b) => {
    if (a !== b) redrawVis()
  })
  watch(escapeKey, (pressed) => {
    if (pressed) close()
  })

  onMounted(() => {
    setupVis()
  })

  onBeforeUnmount(() => {
    if (timeoutVis) {
      clearTimeout(timeoutVis)
    }
  })

  return {
    sqlLimits, // @/globals/mysqlLimits

    ipLogFields, // ../_config/
    iplogSortBy,
    iplogSortDesc,

    locationLogFields, // ../_config/
    locationSortBy,
    locationSortDesc,

    securityEventFields, // ../_config/
    securityEventSortBy,
    securityEventSortDesc,

    dhcpOption82Fields, // ../_config/
    dhcpOption82SortBy,
    dhcpOption82SortDesc,

    triggerSecurityEvent,
    visGroups,
    visItems,
    visOptions,

    form,
    node,
    rolesWithNull,
    securityEvents,
    statuses,
    escapeKey,

    onRelease,
    connectionSubType,
    securityEventDescription,
    setupVis,
    addVisGroup,
    addVisItem,
    redrawVis
  }
}

// @vue/component
export default {
  name: 'node-view',
  components,
  props,
  setup
}
</script>

<style lang="scss">
$vis-item-bg: theme-color("primary");
$vis-item-color: $white;

.vis-timeline {
  border: none;
}

.vis-labelset .vis-label,
.vis-foreground .vis-group {
  border-bottom-color: $table-border-color;
}

.vis-text,
.vis-label,
.vis-item {
  font-family: $font-family-sans-serif;
  font-size: $font-size-sm;
  font-weight: $font-weight-normal;
  line-height: $line-height-sm;
  white-space: normal;
}
.vis-text.vis-major {
  font-size: $font-size-base;
}
.vis-label,
.vis-labelset .vis-label {
  color: $gray-600;
  font-weight: 500;
  text-align: right;
}
.vis-item {
  padding: 2px 3px 1px;
  background-color: $gray-200;
  color: $vis-item-bg;
  text-align: center;
}
/* bottom arrow on box */
.vis-item.vis-box:after {
  content:'';
  position: absolute;
  top: 100%;
  left: 50%;
  width: 0;
  height: 0;
  border-top: solid 10px $vis-item-bg;
  border-right: solid 10px transparent;
  border-left: solid 10px transparent;
  margin-left: -10px;
}
/* left and right border on range */
.vis-item.vis-range {
  border-right: 5px solid $vis-item-bg;
  border-left: 5px solid $vis-item-bg;
  border-radius: 50px;
}
/* alternating column backgrounds */
.vis-time-axis .vis-grid.vis-odd {
  background: $gray-100;
}
/* gray background in weekends, white text color */
.vis-time-axis .vis-grid.vis-saturday,
.vis-time-axis .vis-grid.vis-sunday {
  background: $gray-700;
}
.vis-time-axis .vis-text.vis-saturday,
.vis-time-axis .vis-text.vis-sunday {
  color: $white;
}
/* match bootstrap tooltip style */
div.vis-tooltip {
  z-index: $zindex-tooltip;
  padding: $tooltip-padding-y $tooltip-padding-x;

  background-color: $tooltip-bg;
  color: $tooltip-color;

  font-family: $font-family-sans-serif;
  font-size: $tooltip-font-size;

  border-radius: $tooltip-border-radius;
  box-shadow: none;

  opacity: $tooltip-opacity;
}
</style>
