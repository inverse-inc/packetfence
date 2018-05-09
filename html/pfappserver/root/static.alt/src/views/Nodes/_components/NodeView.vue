
<template>
  <b-form>
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">MAC {{ mac }}</h4>
      </b-card-header>
      <b-tabs card>

        <b-tab title="Info" active>
          <b-row>
            <b-col>
              <pf-form-row id="pid" label="Owner">
                <b-form-input id="pid" v-model="node.pid"></b-form-input>
              </pf-form-row>
              <pf-form-row id="status" label="Status">
                <b-form-input v-model="node.status"></b-form-input>
              </pf-form-row>
              <pf-form-row id="category_id" label="Role">
                <b-form-input v-model="node.category_id"></b-form-input>
              </pf-form-row>
            </b-col>
            <b-col>
              <pf-form-row label="Name">
                {{ node.computername }}
              </pf-form-row>
              <pf-form-row label="Last Seen">
                {{ node.last_seen }}
              </pf-form-row>
              <pf-form-row label="IPv4 Address" v-if="node.ip4">
                {{ node.ip4.ip }}
                  <b-badge variant="success" v-if="node.ip4.active">Since {{node.ip4.start_time}}</b-badge>
                  <b-badge variant="warning" v-else>Inactive since {{node.ip4.end_time}}</b-badge>
              </pf-form-row>
              <pf-form-row label="IPv6 Address">
                {{ node.ip6 }}
              </pf-form-row>
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="Fingerbank">
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
      <b-card-footer>
        <b-button variant="outline-primary" type="submit" v-t="'Save'"></b-button>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
// import Vue from 'vue'
import ToggleButton from '@/components/ToggleButton'
import pfFormRow from '@/components/pfFormRow'
import { pfEapType as eapType } from '@/globals/pfEapType'

export default {
  name: 'NodeView',
  components: {
    'toggle-button': ToggleButton,
    'pf-form-row': pfFormRow
  },
  props: {
    mac: String
  },
  data () {
    return {
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
  computed: {
    node () {
      return this.$store.state.$_nodes.nodes[this.mac] || {}
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
    }
  },
  mounted () {
    this.$store.dispatch('$_nodes/getNode', this.mac)
    this.$store.dispatch('config/getViolations')
  }
}
</script>

