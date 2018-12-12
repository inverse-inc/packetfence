
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">MAC <strong v-text="mac"></strong></h4>
      </b-card-header>
      <b-tabs ref="tabs" v-model="tabIndex" card>

        <b-tab title="Edit" active>
          <template slot="title">
            {{ $t('Edit') }}
          </template>
          <b-row>
            <b-col>
              <pf-form-input :column-label="$t('Owner')"
                v-model="nodeContent.pid"
                :vuelidate="$v.nodeContent.pid"
              />
              <pf-form-select :column-label="$t('Status')"
                v-model="nodeContent.status"
                :options="statuses"
                :vuelidate="$v.nodeContent.status"
              />
              <pf-form-select :column-label="$t('Role')"
                v-model="nodeContent.category_id"
                :options="rolesWithNull"
                :vuelidate="$v.nodeContent.category_id"
              />
              <pf-form-datetime :column-label="$t('Unregistration')"
                v-model="nodeContent.unregdate"
                :moments="['1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
                :vuelidate="$v.nodeContent.unregdate"
              ></pf-form-datetime>
              <pf-form-input :column-label="$t('Access Time Balance')"
                v-model="nodeContent.time_balance"
                :text="$t('seconds')"
                :vuelidate="$v.nodeContent.time_balance"
                type="number"
              />
              <pf-form-prefix-multiplier :column-label="$t('Bandwidth Balance')"
                v-model="nodeContent.bandwidth_balance"
                :max="globals.sqlLimits.ubigint.max"
                :vuelidate="$v.nodeContent.bandwidth_balance"
              ></pf-form-prefix-multiplier>
              <pf-form-toggle :column-label="$t('VOIP')"
                v-model="nodeContent.voip"
                :values="{checked: 'yes', unchecked: 'no'}"
                :vuelidate="$v.nodeContent.voip"
              >{{ (nodeContent.voip === 'yes') ? $t('Yes') : $t('No') }}</pf-form-toggle>
              <pf-form-input :column-label="$t('Bypass VLAN')"
                v-model="nodeContent.bypass_vlan"
                :vuelidate="$v.nodeContent.bypass_vlan"
                type="text"
              />
              <pf-form-select :column-label="$t('Bypass Role')"
                v-model="nodeContent.bypass_role_id"
                :options="rolesWithNull"
                :vuelidate="$v.nodeContent.bypass_role_id"
              ></pf-form-select>
              <pf-form-textarea :column-label="$t('Notes')"
                v-model="nodeContent.notes"
                :vuelidate="$v.nodeContent.notes"
                rows="3" max-rows="3"
              />
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="Info">
          <template slot="title">
            {{ $t('Info') }}
          </template>
          <!--
          <p class="h3 border border-left-0 border-top-0 border-right-0 pb-3 mb-3">{{ $t('Edit Node') }}</p>
          -->
          <b-row>
            <b-col>
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
            <b-col>
              <pf-form-row class="text-nowrap" :column-label="$t('Device Class')">
                {{ node.device_class }}
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
                {{ node.device_vendor }}
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
          <template slot="title">
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
            <template slot="title">
              {{ $t('IPv4') }} <b-badge pill v-if="node.ip4 && node.ip4.history && node.ip4.history.length > 0" variant="light" class="ml-1">{{ node.ip4.history.length }}</b-badge>
            </template>
            <b-table stacked="sm" :items="node.ip4.history" :fields="iplogFields" v-if="node.ip4" striped></b-table>
        </b-tab>

        <b-tab title="IPv6 Addresses">
            <template slot="title">
              {{ $t('IPv6') }} <b-badge pill v-if="node.ip6 && node.ip6.history && node.ip6.history.length > 0" variant="light" class="ml-1">{{ node.ip6.history.length }}</b-badge>
            </template>
            <b-table stacked="sm" :items="node.ip6.history" :fields="iplogFields" v-if="node.ip6" striped></b-table>
        </b-tab>

        <b-tab title="Location">
            <template slot="title">
              {{ $t('Location') }} <b-badge pill v-if="node.locations && node.locations.length > 0" variant="light" class="ml-1">{{ node.locations.length }}</b-badge>
            </template>
            <b-table stacked="sm" :items="node.locations" :fields="locationFields" striped>
                <template slot="switch" slot-scope="location">
                    {{ location.item.switch_ip }} / <mac>{{ location.item.switch_mac }}</mac><br/>
                    <b-badge><icon name="wifi" size="sm"></icon> {{ location.item.ssid }}</b-badge>
                    <b-badge>{{ $t('Role') }}: {{ location.item.role }}</b-badge>
                    <b-badge>{{ $t('VLAN') }}: {{ location.item.vlan }}</b-badge>
                </template>
                <template slot="connection_type" slot-scope="location">
                    {{ location.item.connection_type }} {{ connectionSubType(location.item.connection_sub_type) }}
                </template>
            </b-table>
        </b-tab>

        <b-tab title="Violations">
            <template slot="title">
              {{ $t('Violations') }} <b-badge pill v-if="node.violations && node.violations.length > 0" variant="light" class="ml-1">{{ node.violations.length }}</b-badge>
            </template>
            <b-table stacked="sm" :items="node.violations" :fields="violationFields" striped>
                <template slot="description" slot-scope="violation">
                    {{ violationDescription(violation.item.vid) }}
                </template>
                <template slot="status" slot-scope="violation">
                  <b-badge pill variant="success" v-if="violation.item.status === 'open'">{{ $t('open') }}</b-badge>
                  <b-badge pill variant="danger" v-else-if="violation.item.status === 'closed'">{{ $t('closed') }}</b-badge>
                  <b-badge pill variant="secondary" v-else>{{ $t('unknown') }}</b-badge>
                </template>
            </b-table>
        </b-tab>

        <b-tab title="WMI Rules">
          <template slot="title">
            {{ $t('WMI Rules') }}
          </template>
        </b-tab>

        <b-tab title="Option82">
          <template slot="title">
            {{ $t('Option82') }} <b-badge pill v-if="node.dhcpoption82 && node.dhcpoption82.length > 0" variant="light" class="ml-1">{{ node.dhcpoption82.length }}</b-badge>
          </template>
          <b-table stacked="sm" :items="node.dhcpoption82" :fields="dhcpOption82Fields" v-if="node.dhcpoption82" striped></b-table>
        </b-tab>

      </b-tabs>
      <b-card-footer @mouseenter="$v.nodeContent.$touch()" v-if="ifTab(['Edit', 'Location', 'Fingerbank'])">
        <pf-button-save class="mr-1" v-if="ifTab(['Edit'])" :disabled="invalidForm" :isLoading="isLoading"/>
        <pf-button-delete class="mr-3" v-if="ifTab(['Edit'])" :disabled="isLoading" :confirm="$t('Delete Node?')" @on-delete="deleteNode()"/>
        <b-button class="mr-1" size="sm" v-if="ifTab(['Edit', 'Location'])" variant="outline-secondary" @click="applyReevaluateAccess" :disabled="!canReevaluateAccess(node)">{{ $t('Reevaulate Access') }}</b-button>
        <b-button class="mr-1" size="sm" v-if="ifTab(['Edit', 'Fingerbank'])" variant="outline-secondary" @click="applyRefreshFingerbank">{{ $t('Refresh Fingerbank') }}</b-button>
        <b-button size="sm" v-if="ifTab(['Edit', 'Location'])" variant="outline-secondary" @click="applyRestartSwitchport" :disabled="!canRestartSwitchport(node)">{{ $t('Restart Switch Port') }}</b-button>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import { DataSet, Timeline } from 'vue2vis'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFingerbankScore from '@/components/pfFingerbankScore'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfFormRow from '@/components/pfFormRow'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import { mysqlLimits as sqlLimits } from '@/globals/mysqlLimits'
import { pfEapType as eapType } from '@/globals/pfEapType'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import {
  pfDatabaseSchema as schema,
  buildValidationFromTableSchemas
} from '@/globals/pfDatabaseSchema'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'
import network from '@/utils/network'

const { validationMixin } = require('vuelidate')
const { required } = require('vuelidate/lib/validators')

export default {
  name: 'NodeView',
  components: {
    'timeline': Timeline,
    pfButtonSave,
    pfButtonDelete,
    pfFingerbankScore,
    pfFormDatetime,
    pfFormInput,
    pfFormRow,
    pfFormPrefixMultiplier,
    pfFormSelect,
    pfFormTextarea,
    pfFormToggle
  },
  mixins: [
    validationMixin
  ],
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    mac: String
  },
  data () {
    return {
      globals: {
        regExp: regExp,
        sqlLimits: sqlLimits
      },
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
        stack: false,
        tooltip: {
          followMouse: true
        }
      },
      tabIndex: 0,
      tabTitle: '',
      nodeContent: {
        pid: ''
      },
      iplogFields: [
        {
          key: 'ip',
          label: this.$i18n.t('IP Address')
        },
        {
          key: 'start_time',
          label: this.$i18n.t('Start Time'),
          formatter: this.$options.filters.shortDateTime,
          class: 'text-nowrap'
        },
        {
          key: 'end_time',
          label: this.$i18n.t('End Time'),
          formatter: this.$options.filters.shortDateTime,
          class: 'text-nowrap'
        },
        {
          key: 'type',
          label: this.$i18n.t('Type')
        }
      ],
      locationFields: [
        {
          key: 'switch',
          label: this.$i18n.t('Switch/AP')
        },
        {
          key: 'connection_type',
          label: this.$i18n.t('Connection Type')
        },
        {
          key: 'dot1x_username',
          label: this.$i18n.t('Username')
        },
        {
          key: 'start_time',
          label: this.$i18n.t('Start Time'),
          class: 'text-nowrap'
        },
        {
          key: 'end_time',
          label: this.$i18n.t('End Time'),
          formatter: this.$options.filters.shortDateTime,
          class: 'text-nowrap'
        }
      ],
      violationFields: [
        {
          key: 'description',
          label: this.$i18n.t('Violation')
        },
        {
          key: 'start_date',
          label: this.$i18n.t('Start Time'),
          class: 'text-nowrap'
        },
        {
          key: 'release_date',
          label: this.$i18n.t('Release Date'),
          class: 'text-nowrap'
        },
        {
          key: 'status',
          label: this.$i18n.t('Status'),
          class: 'text-nowrap'
        }
      ],
      dhcpOption82Fields: [
        {
          key: 'created_at',
          label: this.$i18n.t('Created At'),
          formatter: this.$options.filters.shortDateTime,
          class: 'text-nowrap'
        },
        {
          key: 'vlan',
          label: this.$i18n.t('VLAN')
        },
        {
          key: 'switch_id',
          label: this.$i18n.t('Switch IP'),
          class: 'text-nowrap'
        },
        {
          key: 'option82_switch',
          label: this.$i18n.t('Switch MAC'),
          class: 'text-nowrap'
        },
        {
          key: 'port',
          label: this.$i18n.t('Port')
        },
        {
          key: 'module',
          label: this.$i18n.t('Module')
        },
        {
          key: 'host',
          label: this.$i18n.t('Host')
        }
      ]
    }
  },
  validations () {
    return {
      nodeContent: buildValidationFromTableSchemas(
        schema.node, // use `node` table schema
        {
          // additional custom validations ...
          pid: {
            [this.$i18n.t('Username required.')]: required
          }
        }
      )
    }
  },
  computed: {
    node () {
      return this.$store.state.$_nodes.nodes[this.mac]
    },
    roles () {
      return this.$store.getters['config/rolesList']
    },
    rolesWithNull () {
      // prepend a null value to roles
      return [{ value: null, text: this.$i18n.t('No Role') }, ...this.$store.getters['config/rolesList']]
    },
    violations () {
      return this.$store.getters['config/sortedViolations']
    },
    statuses () {
      return conditionValues[conditionType.NODE_STATUS]
    },
    isLoading () {
      return this.$store.getters['$_nodes/isLoading']
    },
    invalidForm () {
      return this.$v.nodeContent.$invalid || this.$store.getters['$_nodes/isLoading']
    }
  },
  methods: {
    ifTab (set) {
      return this.$refs.tabs && set.includes(this.$refs.tabs.tabs[this.tabIndex].title)
    },
    applyReevaluateAccess () {
      this.$store.dispatch(`${this.storeName}/reevaluateAccessNode`, this.mac).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Node access reevaluation initialized') })
      }).catch((response) => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Node access reevaluation failed') })
      })
    },
    applyRefreshFingerbank () {
      this.$store.dispatch(`${this.storeName}/refreshFingerbankNode`, this.mac).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Node device profiling initialized') })
      }).catch((response) => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Node device profiling failed') })
      })
    },
    applyRestartSwitchport () {
      this.$store.dispatch(`${this.storeName}/restartSwitchportNode`, this.mac).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Node switchport restarted') })
      }).catch((response) => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Node switchport restart failed') })
      })
    },
    canReevaluateAccess (node) {
      return (node.locations && node.locations.length > 0 && ((node.ip4 && node.ip4.ip) || (node.ip6 && node.ip6.ip)))
    },
    canRestartSwitchport (node) {
      return (node.locations && node.locations.filter(node =>
        node.end_time === '0000-00-00 00:00:00' && // require zero end_time
        network.connectionTypeToAttributes(node.connection_type).isWired // require 'Wired'
      ).length > 0)
    },
    close () {
      this.$router.push({ name: 'nodes' })
    },
    connectionSubType (type) {
      if (type && eapType[type]) {
        return eapType[type]
      }
    },
    violationDescription (id) {
      return this.$store.state.config.violations[id].desc
    },
    save () {
      this.$store.dispatch('$_nodes/updateNode', this.nodeContent).then(response => {
        this.close()
      })
    },
    deleteNode () {
      this.$store.dispatch('$_nodes/deleteNode', this.mac).then(response => {
        this.close()
      })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    },
    redrawVis () {
      // buffer async calls to redraw
      if (this.timeoutVis) clearTimeout(this.timeoutVis)
      this.timeoutVis = setTimeout(this.setupVis, 100)
    },
    setupVis () {
      const node = this.$store.state.$_nodes.nodes[this.mac]
      const _this = this
      if (node.detect_date && node.detect_date !== '0000-00-00 00:00:00') {
        _this.addVisGroup({
          id: this.mac + '-seen',
          content: this.$i18n.t('Seen')
        })
        _this.addVisItem({
          id: 'detect',
          group: this.mac + '-seen',
          start: new Date(node.detect_date),
          end: (node.last_seen && node.last_seen !== '0000-00-00 00:00:00' && node.last_seen !== node.detect_date) ? new Date(node.last_seen) : null,
          content: this.$i18n.t('Detected')
        })
      } else if (node.last_seen && node.last_seen !== '0000-00-00 00:00:00') {
        _this.addVisGroup({
          id: this.mac + '-seen',
          content: this.$i18n.t('Seen')
        })
        this.addVisItem({
          id: 'last_seen',
          group: this.mac + '-seen',
          start: new Date(node.last_seen),
          content: this.$i18n.t('Last Seen')
        })
      }
      if (node.regdate && node.regdate !== '0000-00-00 00:00:00') {
        _this.addVisGroup({
          id: this.mac + '-registered',
          content: this.$i18n.t('Registered')
        })
        _this.addVisItem({
          id: 'regdate',
          group: this.mac + '-registered',
          start: new Date(node.regdate),
          end: (node.unregdate && node.unregdate !== '0000-00-00 00:00:00' && node.unregdate !== node.regdate) ? new Date(node.unregdate) : null,
          content: this.$i18n.t('Registered')
        })
      }
      if (node.last_arp && node.last_arp !== '0000-00-00 00:00:00') {
        _this.addVisGroup({
          id: this.mac + '-general',
          content: this.$i18n.t('General')
        })
        _this.addVisItem({
          id: 'last_arp',
          group: this.mac + '-general',
          start: new Date(node.last_arp),
          content: this.$i18n.t('Last ARP')
        })
      }
      if (node.last_dhcp && node.last_dhcp !== '0000-00-00 00:00:00') {
        _this.addVisGroup({
          id: this.mac + '-general',
          content: this.$i18n.t('General')
        })
        _this.addVisItem({
          id: 'last_dhcp',
          group: this.mac + '-general',
          start: new Date(node.last_dhcp),
          content: this.$i18n.t('Last DHCP')
        })
      }
      if (node.lastskip && node.lastskip !== '0000-00-00 00:00:00') {
        _this.addVisGroup({
          id: this.mac + '-general',
          content: this.$i18n.t('General')
        })
        _this.addVisItem({
          id: 'lastskip',
          group: this.mac + '-general',
          start: new Date(node.lastskip),
          content: this.$i18n.t('Last Skip')
        })
      }
      try {
        node.ip4.history.forEach(function (ip4, index, ip4s) {
          _this.addVisGroup({
            id: _this.mac + '-ipv4',
            content: _this.$i18n.t('IPv4 Addresses')
          })
          _this.addVisItem({
            id: 'ipv4-' + ip4.ip,
            group: _this.mac + '-ipv4',
            start: new Date(ip4.start_time),
            end: (ip4.end_time !== '0000-00-00 00:00:00' && ip4.end_time !== ip4.start_time) ? new Date(ip4.end_time) : null,
            content: ip4.ip
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.ip6.history.forEach(function (ip6, index, ip6s) {
          _this.addVisGroup({
            id: _this.mac + '-ipv6',
            content: _this.$i18n.t('IPv6 Addresses')
          })
          _this.addVisItem({
            id: 'ipv6-' + ip6.ip,
            group: _this.mac + '-ipv6',
            start: new Date(ip6.start_time),
            end: (ip6.end_time !== '0000-00-00 00:00:00' && ip6.end_time !== ip6.start_time) ? new Date(ip6.end_time) : null,
            content: ip6.ip
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.locations.forEach(function (location, index, locations) {
          _this.addVisGroup({
            id: _this.mac + '-location',
            content: _this.$i18n.t('Locations')
          })
          _this.addVisItem({
            id: 'location-' + location.id,
            group: _this.mac + '-location',
            start: new Date(location.start_time),
            end: (location.end_time && location.end_time !== '0000-00-00 00:00:00' && location.end_time !== location.start_time) ? new Date(location.end_time) : null,
            content: location.ssid + '/' + _this.$i18n.t('Role') + ':' + location.role + '/VLAN:' + location.vlan
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.violations.forEach(function (violation, index, violations) {
          _this.addVisGroup({
            id: _this.mac + '-violation',
            content: _this.$i18n.t('Violations')
          })
          _this.addVisItem({
            id: 'violation' + violation.vid,
            group: _this.mac + '-violation',
            start: new Date(violation.start_date),
            end: (violation.release_date !== '0000-00-00 00:00:00' && violation.release_date !== violation.start_date) ? new Date(violation.release_date) : null,
            content: _this.violationDescription(violation.vid)
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.dhcpoption82.forEach(function (dhcpoption82, index, dhcpoption82s) {
          _this.addVisGroup({
            id: _this.mac + '-dhcpoption82',
            content: _this.$i18n.t('DHCP Option 82')
          })
          _this.addVisItem({
            id: 'dhcpoption82' + dhcpoption82.created_at,
            group: _this.mac + '-dhcpoption82',
            start: new Date(dhcpoption82.created_at),
            content: ((dhcpoption82.switch_id) ? (dhcpoption82.switch_id + '/') : '') + ((dhcpoption82.port) ? _this.$i18n.t('Port') + ':' + dhcpoption82.port + '/' : '') + 'VLAN:' + dhcpoption82.vlan
          })
        })
      } catch (e) {
        // noop
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
    }
  },
  watch: {
    node: {
      handler: function (a, b) {
        this.redrawVis()
      },
      deep: true
    },
    'node.ip4': {
      handler: function (a, b) {
        this.redrawVis()
      },
      deep: true
    },
    'node.ip6': {
      handler: function (a, b) {
        this.redrawVis()
      },
      deep: true
    },
    'node.locations': {
      handler: function (a, b) {
        this.redrawVis()
      },
      deep: true
    },
    'node.violations': {
      handler: function (a, b) {
        this.redrawVis()
      },
      deep: true
    },
    'node.dhcpoption82': {
      handler: function (a, b) {
        this.redrawVis()
      },
      deep: true
    },
    violations (a, b) {
      if (a !== b) this.redrawVis()
    }
  },
  created () {
    this.$store.dispatch('$_nodes/getNode', this.mac).then(data => {
      this.nodeContent = Object.assign({}, data)
    })
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getViolations')
  },
  mounted () {
    this.setupVis()
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
    if (this.timeoutVis) {
      clearTimeout(this.timeoutVis)
    }
  }
}
</script>

<style lang="scss">
@import "../../../../node_modules/bootstrap/scss/functions";
@import "../../../styles/variables";

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
  background-color: $gray-200;
  color: $vis-item-bg;
  padding: 2px 3px 1px;
  text-align: center;
}
/* bottom arrow on box */
.vis-item.vis-box:after {
  content:'';
  position: absolute;
  top: 100%;
  left: 50%;
  margin-left: -10px;
  width: 0;
  height: 0;
  border-top: solid 10px $vis-item-bg;
  border-left: solid 10px transparent;
  border-right: solid 10px transparent;
}
/* left and right border on range */
.vis-item.vis-range {
  border-left: 5px solid $vis-item-bg;
  border-right: 5px solid $vis-item-bg;
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
  font-family: $font-family-sans-serif;
  font-size: $tooltip-font-size;

  color: $tooltip-color;
  background-color: $tooltip-bg;

  border-radius: $tooltip-border-radius;
  box-shadow: none;

  opacity: $tooltip-opacity;
  padding: $tooltip-padding-y $tooltip-padding-x;

  z-index: $zindex-tooltip;
}
</style>
