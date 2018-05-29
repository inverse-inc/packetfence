
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">MAC <strong v-text="mac"></strong></h4>
      </b-card-header>
      <b-tabs card>

        <b-tab title="Info" active>
          <b-row>
            <b-col>
              <pf-form-input v-model="nodeContent.pid" label="Owner" :validation="$v.nodeContent.pid"/>
              <b-form-group horizontal label-cols="3" :label="$t('Status')">
                <b-form-select v-model="nodeContent.status" :options="statuses"></b-form-select>
             </b-form-group>
              <b-form-group horizontal label-cols="3" :label="$t('Role')">
                <b-form-select v-model="nodeContent.category" :options="roles"></b-form-select>
             </b-form-group>
              <b-form-group horizontal label-cols="3" :label="$t('Notes')">
                <b-form-textarea v-model="nodeContent.notes" rows="4" max-rows="6"></b-form-textarea>
              </b-form-group>
            </b-col>
            <b-col>
              <pf-form-row :label="$t('Name')">
                {{ node.computername }}
              </pf-form-row>
              <pf-form-row :label="$t('Last Seen')">
                {{ node.last_seen }}
              </pf-form-row>
              <pf-form-row :label="$t('IPv4 Address')" v-if="node.ip4">
                {{ node.ip4.ip }}
                  <b-badge variant="success" v-if="node.ip4.active">{{ $t('Since') }} {{ node.ip4.start_time }}</b-badge>
                  <b-badge variant="warning" v-else-if="node.ip4.end_time">{{ $t('Inactive since') }} {{ node.ip4.end_time }}</b-badge>
                  <b-badge variant="danger" v-else>{{ $t('Inactive') }}</b-badge>
              </pf-form-row>
              <pf-form-row :label="$t('IPv6 Address')" v-if="node.ip6">
                {{ node.ip6.ip }}
                  <b-badge variant="success" v-if="node.ip6.active">{{ $t('Since') }} {{ node.ip6.start_time }}</b-badge>
                  <b-badge variant="warning" v-else-if="node.ip6.end_time">{{ $t('Inactive since') }} {{ node.ip6.end_time }}</b-badge>
                  <b-badge variant="danger" v-else>{{ $t('Inactive') }}</b-badge>
              </pf-form-row>
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="Fingerbank">
          <b-row>
            <b-col>
              <pf-form-row :label="$t('Device Class')">
                {{ node.device_class }}
              </pf-form-row>
              <pf-form-row :label="$t('Device Type')">
                {{ node.device_type }}
              </pf-form-row>
              <pf-form-row :label="$t('Fully Qualified Device Name')">
                {{ node.fingerbank.device_fq }}
              </pf-form-row>
              <pf-form-row :label="$t('Version')">
                {{ node.fingerbank.version }}
              </pf-form-row>
              <pf-form-row :label="$t('Score')" v-if="node.fingerbank.score">
                <pf-fingerbank-score :score="node.fingerbank.score"></pf-fingerbank-score>
              </pf-form-row>
              <pf-form-row :label="$t('Mobile')">
                <b-badge variant="success" v-if="node.fingerbank.mobile === 1">{{ $t('Yes') }}</b-badge>
                <b-badge variant="danger" v-else-if="node.fingerbank.mobile === 0">{{ $t('No') }}</b-badge>
                <b-badge variant="light" v-else>{{ $t('Unknown') }}</b-badge>
              </pf-form-row>
              <pf-form-row :label="$t('DHCP Fingerprint')">
                {{ node.dhcp_fingerprint }}
              </pf-form-row>
              <pf-form-row :label="$t('DHCP Vendor')">
                {{ node.device_vendor }}
              </pf-form-row>
              <pf-form-row :label="$t('DHCPv6 Fingerprint')">
                {{ node.dhcp6_fingerprint }}
              </pf-form-row>
              <pf-form-row :label="$t('DHCPv6 Enterprise')">
                {{ node.dhcp6_enterprise }}
              </pf-form-row>
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="IPv4 Addresses">
            <b-table stacked="sm" :items="node.ip4.history" :fields="iplogFields" v-if="node.ip4"></b-table>
        </b-tab>

        <b-tab title="IPv6 Addresses">
            <b-table stacked="sm" :items="node.ip6.history" :fields="iplogFields" v-if="node.ip6"></b-table>
        </b-tab>

        <b-tab title="Location">
            <b-table stacked="sm" :items="node.locations" :fields="locationFields">
                <template slot="switch" slot-scope="location">
                    {{ location.item.switch_ip }} / {{ location.item.switch_mac }}<br/>
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
            <b-table stacked="sm" :items="node.violations" :fields="violationFields">
                <template slot="description" slot-scope="violation">
                    {{ violationDescription(violation.item.vid) }}
                </template>
            </b-table>
        </b-tab>

        <b-tab title="WMI Rules">
        </b-tab>

        <b-tab title="Option82">
        </b-tab>

      </b-tabs>
      <b-card-footer align="right" @mouseenter="$v.nodeContent.$touch()">
        <b-button variant="outline-danger" class="mr-1" :disabled="isLoading" @click="deleteNode()" v-t="'Delete'"></b-button>
        <b-button variant="outline-primary" type="submit" :disabled="invalidForm"><icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Save') }}</b-button>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import ToggleButton from '@/components/ToggleButton'
import pfFingerbankScore from '@/components/pfFingerbankScore'
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'
import { pfEapType as eapType } from '@/globals/pfEapType'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'
const { validationMixin } = require('vuelidate')
const { required } = require('vuelidate/lib/validators')

export default {
  name: 'NodeView',
  components: {
    'toggle-button': ToggleButton,
    'pf-fingerbank-score': pfFingerbankScore,
    'pf-form-row': pfFormRow,
    'pf-form-input': pfFormInput
  },
  mixins: [
    validationMixin
  ],
  props: {
    mac: String
  },
  data () {
    return {
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
          'class': 'text-nowrap'
        },
        {
          key: 'end_time',
          label: this.$i18n.t('End Time'),
          formatter: this.$options.filters.pfDate,
          'class': 'text-nowrap'
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
          'class': 'text-nowrap'
        },
        {
          key: 'end_time',
          label: this.$i18n.t('End Time'),
          formatter: this.$options.filters.pfDate,
          'class': 'text-nowrap'
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
          'class': 'text-nowrap'
        },
        {
          key: 'release_date',
          label: this.$i18n.t('Release Date'),
          'class': 'text-nowrap'
        }
      ]
    }
  },
  validations: {
    nodeContent: {
      pid: { required }
    }
  },
  computed: {
    node () {
      return this.$store.state.$_nodes.nodes[this.mac]
    },
    roles () {
      return this.$store.getters['config/rolesList']
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
    }
  },
  mounted () {
    this.$store.dispatch('$_nodes/getNode', this.mac).then(data => {
      this.nodeContent = Object.assign({}, data)
    })
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getViolations')
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>
