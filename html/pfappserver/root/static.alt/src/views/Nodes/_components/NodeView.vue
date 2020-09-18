<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <pf-button-refresh class="border-right pr-3" :isLoading="isLoading" @refresh="refresh"></pf-button-refresh>
        <h4 class="mb-0">MAC <strong v-text="mac"></strong></h4>
      </b-card-header>
      <b-tabs ref="tabs" v-model="tabIndex" card>

        <b-tab title="Edit" active>
          <template v-slot:title>
            {{ $t('Edit') }}
          </template>
          <b-row>
            <b-col>
              <pf-form-autocomplete :column-label="$t('Owner')"
                :form-store-name="formStoreName" form-namespace="pid"
                :suggestions="matchingUsers"
                placeholder="default"
                @search="searchUsers"
              />
              <pf-form-select :column-label="$t('Status')"
                :form-store-name="formStoreName" form-namespace="status"
                :options="statuses"
              />
              <pf-form-select :column-label="$t('Role')"
                :form-store-name="formStoreName" form-namespace="category_id"
                :options="rolesWithNull"
              />
              <pf-form-datetime :column-label="$t('Unregistration')"
                :form-store-name="formStoreName" form-namespace="unregdate"
                :moments="['1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
              />
              <pf-form-input :column-label="$t('Access Time Balance')"
                :form-store-name="formStoreName" form-namespace="time_balance"
                :text="$t('Seconds')"
                type="number"
              />
              <pf-form-prefix-multiplier :column-label="$t('Bandwidth Balance')"
                :form-store-name="formStoreName" form-namespace="bandwidth_balance"
                :max="sqlLimits.ubigint.max"
              />
              <pf-form-range-toggle :column-label="$t('Voice Over IP')"
                :form-store-name="formStoreName" form-namespace="voip"
                :values="{checked: 'yes', unchecked: 'no'}"
                :rightLabels="{checked: $t('Yes'), unchecked: $t('No')}"
              />
              <pf-form-input :column-label="$t('Bypass VLAN')"
                :form-store-name="formStoreName" form-namespace="bypass_vlan"
                type="text"
              />
              <pf-form-select :column-label="$t('Bypass Role')"
                :form-store-name="formStoreName" form-namespace="bypass_role_id"
                :options="rolesWithNull"
              />
              <pf-form-textarea :column-label="$t('Notes')"
                :form-store-name="formStoreName" form-namespace="notes"
                rows="3" max-rows="3"
              />
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="Info">
          <template v-slot:title>
            {{ $t('Info') }}
          </template>
          <!--
          <p class="h3 border border-left-0 border-top-0 border-right-0 pb-3 mb-3">{{ $t('Edit Node') }}</p>
          -->
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
                {{ node.detect_date | longDateTime }}
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

        <b-tab title="Fingerbank">
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
        </b-tab>

        <b-tab title="Timeline">
          <template v-slot:title>
            {{ $t('Timeline') }}
          </template>
          <b-row>
            <b-col>
              <timeline
                ref="timeline"
                :items="visItems"
                :groups="visGroups"
                :options="visOptions"
              ></timeline>
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="IPv4 Addresses">
          <template v-slot:title>
            {{ $t('IPv4') }} <b-badge pill v-if="node && node.ip4 && node.ip4.history && node.ip4.history.length > 0" variant="light" class="ml-1">{{ node.ip4.history.length }}</b-badge>
          </template>
          <b-table v-if="node && node.ip4"
            :items="node.ip4.history" :fields="ipLogFields" :sort-by="iplogSortBy" :sort-desc="iplogSortDesc" responsive show-empty sort-icon-left striped>
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoading" text="">{{ $t('No IPv4 addresses found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>

        <b-tab title="IPv6 Addresses">
          <template v-slot:title>
            {{ $t('IPv6') }} <b-badge pill v-if="node && node.ip6 && node.ip6.history && node.ip6.history.length > 0" variant="light" class="ml-1">{{ node.ip6.history.length }}</b-badge>
          </template>
          <b-table v-if="node && node.ip6"
            :items="node.ip6.history" :fields="ipLogFields" :sort-by="iplogSortBy" :sort-desc="iplogSortDesc" responsive show-empty sort-icon-left striped>
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoading" text="">{{ $t('No IPv6 addresses found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>

        <b-tab title="Location">
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
                <pf-empty-table :isLoading="isLoading" text="">{{ $t('No location logs found') }}</pf-empty-table>
              </template>
            </b-table>
        </b-tab>

        <b-tab title="SecurityEvents">
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
              <b-button v-if="security_event.item.status === 'open'" size="sm" variant="outline-secondary" @click="release(security_event.item.id)">{{ $t('Release') }}</b-button>
            </template>
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoading" text="">{{ $t('No security events found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>

        <!-- TODO
        <b-tab title="WMI Rules">
          <template v-slot:title>
            {{ $t('WMI Rules') }}
          </template>
        </b-tab>
        -->

        <b-tab title="Option82">
          <template v-slot:title>
            {{ $t('Option82') }} <b-badge pill v-if="node && node.dhcpoption82 && node.dhcpoption82.length > 0" variant="light" class="ml-1">{{ node.dhcpoption82.length }}</b-badge>
          </template>
          <b-table v-if="node && node.dhcpoption82"
            :items="node.dhcpoption82" :fields="dhcpOption82Fields" :sortBy="dhcpOption82SortBy" :sortDesc="dhcpOption82SortDesc" responsive show-empty sort-icon-left striped>
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoading" text="">{{ $t('No DHCP option82 logs found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>

      </b-tabs>
      <b-card-footer v-if="ifTab(['Edit', 'Location', 'Fingerbank', 'SecurityEvents'])">
        <pf-button-save class="mr-1" v-if="ifTab(['Edit'])" :disabled="disableSave" :isLoading="isLoading"/>
        <pf-button-delete class="mr-3" v-if="ifTab(['Edit'])" :disabled="isLoading" :confirm="$t('Delete Node?')" @on-delete="deleteNode()"/>
        <template v-if="ifTab(['Edit', 'Location'])">
          <template v-if="canReevaluateAccess(node)">
            <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="isLoading" @click="applyReevaluateAccess">{{ $t('Reevaluate Access') }}</b-button>
          </template>
          <template v-else>
            <span v-b-tooltip.hover.top.d300 :title="cannotReevaluateAccessTooltip(node)">
              <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="true">{{ $t('Reevaluate Access') }}</b-button>
            </span>
          </template>
        </template>
        <b-button class="mr-1" size="sm" v-if="ifTab(['Edit', 'Fingerbank'])" variant="outline-secondary" :disabled="isLoading" @click="applyRefreshFingerbank">{{ $t('Refresh Fingerbank') }}</b-button>
        <template v-if="ifTab(['Edit', 'Location'])">
          <template v-if="canRestartSwitchport(node)">
            <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="isLoading" @click="applyRestartSwitchport">{{ $t('Restart Switch Port') }}</b-button>
          </template>
          <template v-else>
            <span v-b-tooltip.hover.top.d300 :title="cannotRestartSwitchportTooltip(node)">
              <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="true">{{ $t('Restart Switch Port') }}</b-button>
            </span>
          </template>
        </template>
        <b-row v-if="ifTab(['SecurityEvents']) && securityEventsOptions.length > 0">
          <b-col cols="2" class="pr-0 mr-0">
            <pf-form-select size="sm"
              v-model="triggerSecurityEvent"
              :options="securityEventsOptions"
            />
          </b-col>
          <b-col cols="auto" class="pl-1 ml-0">
            <b-button size="sm" variant="outline-secondary" @click="trigger" :disabled="isLoading || !triggerSecurityEvent">{{ $t('Trigger New Security Event') }}</b-button>
          </b-col>
        </b-row>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import { DataSet, Timeline } from 'vue2vis'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonRefresh from '@/components/pfButtonRefresh'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFingerbankScore from '@/components/pfFingerbankScore'
import pfFormAutocomplete from '@/components/pfFormAutocomplete'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormRow from '@/components/pfFormRow'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import { mysqlLimits as sqlLimits } from '@/globals/mysqlLimits'
import { pfEapType as eapType } from '@/globals/pfEapType'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'
import network from '@/utils/network'
import usersApi from '@/views/Users/_api'

import {
  updateValidators,
  ipLogFields,
  locationLogFields,
  securityEventFields,
  dhcpOption82Fields
} from '../_config/'

export default {
  name: 'node-view',
  components: {
    Timeline,
    pfButtonSave,
    pfButtonDelete,
    pfButtonRefresh,
    pfEmptyTable,
    pfFingerbankScore,
    pfFormAutocomplete,
    pfFormDatetime,
    pfFormInput,
    pfFormRangeToggle,
    pfFormRow,
    pfFormPrefixMultiplier,
    pfFormSelect,
    pfFormTextarea
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    },
    mac: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      sqlLimits, // @/globals/mysqlLimits
      tabIndex: 0,
      tabTitle: '',
      matchingUsers: [],
      nodeContent: {},

      ipLogFields, // ../_config/
      iplogSortBy: 'end_time',
      iplogSortDesc: false,

      locationLogFields, // ../_config/
      locationSortBy: 'start_time',
      locationSortDesc: true,

      securityEventFields, // ../_config/
      securityEventSortBy: 'start_date',
      securityEventSortDesc: true,

      dhcpOption82Fields, // ../_config/
      dhcpOption82SortBy: 'created_at',
      dhcpOption82SortDesc: true,

      triggerSecurityEvent: null,
      visGroups: new DataSet(),
      visItems: new DataSet(),
      visOptions: {
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
      }
    }
  },
  computed: {
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    node () {
      return this.$store.state.$_nodes.nodes[this.mac]
    },
    rolesWithNull () {
      return [
        { value: null, text: this.$i18n.t('No Role') }, // prepend a null value to roles
        ...this.$store.getters['session/allowedNodeRolesList']
      ]
    },
    securityEvents () {
      return this.$store.getters['config/sortedSecurityEvents']
    },
    securityEventsOptions () {
      return this.securityEvents
        .filter(securityEvent => securityEvent.id !== 'defaults')
        .map(securityEvent => { return { text: securityEvent.desc, value: securityEvent.id } })
    },
    statuses () {
      return conditionValues[conditionType.NODE_STATUS]
    },
    isLoading () {
      return this.$store.getters['$_nodes/isLoading']
    },
    disableSave () {
      return this.invalidForm || this.isLoading
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    }
  },
  methods: {
    init () {
      // setup form store module
      this.$store.dispatch(`${this.formStoreName}/clearForm`)
      this.$store.dispatch(`${this.formStoreName}/clearFormValidations`)
      this.$store.dispatch('$_nodes/getNode', this.mac).then(node => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, node)
        this.$store.dispatch(`${this.formStoreName}/setFormValidations`, updateValidators)
      })
    },
    refresh () {
      this.$store.dispatch('$_nodes/refreshNode', this.mac).then(node => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, node)
      })
    },
    save () {
      this.$store.dispatch('$_nodes/updateNode', this.form).then(() => {
        this.close()
      })
    },
    close () {
      this.$router.back()
    },
    release (id) {
      this.$store.dispatch('$_nodes/clearSecurityEventNode', { security_event_id: id, mac: this.mac })
    },
    trigger () {
      this.$store.dispatch('$_nodes/applySecurityEventNode', { security_event_id: this.triggerSecurityEvent, mac: this.mac })
    },
    deleteNode () {
      this.$store.dispatch('$_nodes/deleteNode', this.mac).then(() => {
        this.$router.push('/nodes/search')
      })
    },
    ifTab (set) {
      return this.$refs.tabs && set.includes(this.$refs.tabs.tabs[this.tabIndex].title)
    },
    applyReevaluateAccess () {
      this.$store.dispatch('$_nodes/reevaluateAccessNode', this.mac)
    },
    applyRefreshFingerbank () {
      this.$store.dispatch('$_nodes/refreshFingerbankNode', this.mac)
    },
    applyRestartSwitchport () {
      this.$store.dispatch('$_nodes/restartSwitchportNode', this.mac)
    },
    canReevaluateAccess (node) {
      return (node && node.locations && node.locations.length > 0)
    },
    cannotReevaluateAccessTooltip () {
      return this.$i18n.t('Node has no locations.')
    },
    canRestartSwitchport (node) {
      return (node && node.locations && node.locations.filter(node =>
        node.end_time === '0000-00-00 00:00:00' && // require zero end_time
        network.connectionTypeToAttributes(node.connection_type).isWired // require 'Wired'
      ).length > 0)
    },
    cannotRestartSwitchportTooltip () {
      return this.$i18n.t('Node has no open wired connections.')
    },
    connectionSubType (type) {
      if (type && eapType[type]) {
        return eapType[type]
      }
    },
    securityEventDescription (id) {
      const { $store: { state: { config: { securityEvents: { [id]: { desc = '' } = {} } = {} } = {} } = {} } = {} } = this
      return desc
    },
    setupVis () {
      const node = this.$store.state.$_nodes.nodes[this.mac]
      if (node) {
        if (node.detect_date && node.detect_date !== '0000-00-00 00:00:00') {
          this.addVisGroup({
            id: `${this.mac}-seen`,
            content: this.$i18n.t('Seen')
          })
          this.addVisItem({
            id: 'detect',
            group: `${this.mac}-seen`,
            start: new Date(node.detect_date),
            end: (node.last_seen && node.last_seen !== '0000-00-00 00:00:00' && node.last_seen !== node.detect_date) ? new Date(node.last_seen) : null,
            content: this.$i18n.t('Detected')
          })
        } else if (node.last_seen && node.last_seen !== '0000-00-00 00:00:00') {
          this.addVisGroup({
            id: `${this.mac}-seen`,
            content: this.$i18n.t('Seen')
          })
          this.addVisItem({
            id: 'last_seen',
            group: `${this.mac}-seen`,
            start: new Date(node.last_seen),
            content: this.$i18n.t('Last Seen')
          })
        }
        if (node.regdate && node.regdate !== '0000-00-00 00:00:00') {
          this.addVisGroup({
            id: `${this.mac}-registered`,
            content: this.$i18n.t('Registered')
          })
          this.addVisItem({
            id: 'regdate',
            group: `${this.mac}-registered`,
            start: new Date(node.regdate),
            end: (node.unregdate && node.unregdate !== '0000-00-00 00:00:00' && node.unregdate !== node.regdate) ? new Date(node.unregdate) : null,
            content: this.$i18n.t('Registered')
          })
        }
        if (node.last_arp && node.last_arp !== '0000-00-00 00:00:00') {
          this.addVisGroup({
            id: `${this.mac}-general`,
            content: this.$i18n.t('General')
          })
          this.addVisItem({
            id: 'last_arp',
            group: `${this.mac}-general`,
            start: new Date(node.last_arp),
            content: this.$i18n.t('Last ARP')
          })
        }
        if (node.last_dhcp && node.last_dhcp !== '0000-00-00 00:00:00') {
          this.addVisGroup({
            id: `${this.mac}-general`,
            content: this.$i18n.t('General')
          })
          this.addVisItem({
            id: 'last_dhcp',
            group: `${this.mac}-general`,
            start: new Date(node.last_dhcp),
            content: this.$i18n.t('Last DHCP')
          })
        }
        if (node.lastskip && node.lastskip !== '0000-00-00 00:00:00') {
          this.addVisGroup({
            id: `${this.mac}-general`,
            content: this.$i18n.t('General')
          })
          this.addVisItem({
            id: 'lastskip',
            group: `${this.mac}-general`,
            start: new Date(node.lastskip),
            content: this.$i18n.t('Last Skip')
          })
        }
        try {
          node.ip4.history.forEach(function (ip4) {
            this.addVisGroup({
              id: `${this.mac}-ipv4`,
              content: this.$i18n.t('IPv4 Addresses')
            })
            this.addVisItem({
              id: `ipv4-${ip4.ip}`,
              group: `${this.mac}-ipv4`,
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
            this.addVisGroup({
              id: `${this.mac}-ipv6`,
              content: this.$i18n.t('IPv6 Addresses')
            })
            this.addVisItem({
              id: `ipv6-${ip6.ip}`,
              group: `${this.mac}-ipv6`,
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
            this.addVisGroup({
              id: `${this.mac}-location`,
              content: this.$i18n.t('Locations')
            })
            this.addVisItem({
              id: `location-${location.id}`,
              group: `${this.mac}-location`,
              start: new Date(location.start_time),
              end: (location.end_time && location.end_time !== '0000-00-00 00:00:00' && location.end_time !== location.start_time) ? new Date(location.end_time) : null,
              content: `${location.ssid}/${this.$i18n.t('Role')}:${location.role}/VLAN:${location.vlan}`
            })
          })
        } catch (e) {
          // noop
        }
        try {
          node.security_events.forEach(function (securityEvent) {
            this.addVisGroup({
              id: `${this.mac}-security_event`,
              content: this.$i18n.t('Security Events')
            })
            this.addVisItem({
              id: `security_event-${securityEvent.security_event_id}`,
              group: `${this.mac}-security_event`,
              start: new Date(securityEvent.start_date),
              end: (securityEvent.release_date !== '0000-00-00 00:00:00' && securityEvent.release_date !== securityEvent.start_date) ? new Date(securityEvent.release_date) : null,
              content: this.securityEventDescription(securityEvent.security_event_id)
            })
          })
        } catch (e) {
          // noop
        }
        try {
          node.dhcpoption82.forEach(function (dhcpoption82) {
            this.addVisGroup({
              id: `${this.mac}-dhcpoption82`,
              content: this.$i18n.t('DHCP Option 82')
            })
            this.addVisItem({
              id: `dhcpoption82-${dhcpoption82.created_at}`,
              group: `${this.mac}-dhcpoption82`,
              start: new Date(dhcpoption82.created_at),
              content: ((dhcpoption82.switch_id) ? (`${dhcpoption82.switch_id}/`) : '') + ((dhcpoption82.port) ? `${this.$i18n.t('Port')}:${dhcpoption82.port}/` : '') + `VLAN:${dhcpoption82.vlan}`
            })
          })
        } catch (e) {
          // noop
        }
      }
    },
    addVisGroup (group) {
      if (!this.visGroups.getIds().includes(group.id)) {
        this.visGroups.add([group])
      }
    },
    addVisItem (item) {
      if (!this.visItems.getIds().includes(item.id)) {
        if (!item.title) {
          item.title = item.content
        }
        this.visItems.add([item])
      }
    },
    redrawVis () {
      // buffer async calls to redraw
      if (this.timeoutVis) clearTimeout(this.timeoutVis)
      this.timeoutVis = setTimeout(() => {
        this.setupVis()
        const { $refs: { timeline: { redraw = () => {} } = {} } = {} } = this
        redraw()
      }, 100)
    },
    searchUsers () {
      let body = {
        limit: 10,
        fields: ['pid', 'firstname', 'lastname', 'email'],
        sort: ['pid'],
        query: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'pid', op: 'contains', value: this.form.pid },
              { field: 'firstname', op: 'contains', value: this.form.pid },
              { field: 'lastname', op: 'contains', value: this.form.pid },
              { field: 'email', op: 'contains', value: this.form.pid }
            ]
          }]
        }
      }
      usersApi.search(body).then((data) => {
        this.matchingUsers = data.items.map(item => item.pid)
      })
    }
  },
  watch: {
    node: {
      handler: function () {
        this.redrawVis()
      },
      deep: true
    },
    'node.ip4': {
      handler: function () {
        this.redrawVis()
      },
      deep: true
    },
    'node.ip6': {
      handler: function () {
        this.redrawVis()
      },
      deep: true
    },
    'node.locations': {
      handler: function () {
        this.redrawVis()
      },
      deep: true
    },
    'node.security_events': {
      handler: function () {
        this.redrawVis()
      },
      deep: true
    },
    'node.dhcpoption82': {
      handler: function () {
        this.redrawVis()
      },
      deep: true
    },
    securityEvents (a, b) {
      if (a !== b) this.redrawVis()
    },
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  },
  created () {
    if (this.$can.apply(null, ['read', 'security_events'])) {
      this.$store.dispatch('config/getSecurityEvents')
    }
    this.$store.dispatch('session/getAllowedNodeRoles')
    this.init()
  },
  mounted () {
    this.setupVis()
  },
  beforeDestroy () {
    if (this.timeoutVis) {
      clearTimeout(this.timeoutVis)
    }
  }
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
