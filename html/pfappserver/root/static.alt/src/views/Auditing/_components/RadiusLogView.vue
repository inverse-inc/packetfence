
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('RADIUS Audit Log Entry')}} <strong v-text="id"></strong></h4>
      </b-card-header>
      <b-tabs ref="tabs" v-model="tabIndex" card>

        <b-tab title="Node Information">
          <template slot="title">
            {{ $t('Node Information') }}
          </template>
          <pf-form-row :column-label="$t('MAC Address')"><mac>{{ item.mac }}</mac></pf-form-row>
          <pf-form-row :column-label="$t('Auth Status')">{{ item.auth_status }}</pf-form-row>
          <pf-form-row :column-label="$t('Auth Status')">{{ item.auth_type }}</pf-form-row>
          <pf-form-row :column-label="$t('Auto Registration')">{{ item.auto_reg }}</pf-form-row>
          <pf-form-row :column-label="$t('Calling Station Identifier')"><mac>{{ item.calling_station_id }}</mac></pf-form-row>
          <pf-form-row :column-label="$t('Computer Name')">{{ item.computer_name }}</pf-form-row>
          <pf-form-row :column-label="$t('EAP Type')">{{ item.eap_type }}</pf-form-row>
          <pf-form-row :column-label="$t('Event Type')">{{ item.event_type }}</pf-form-row>
          <pf-form-row :column-label="$t('IP Address')">{{ item.ip }}</pf-form-row>
          <pf-form-row :column-label="$t('Is a Phone')">{{ item.is_phone }}</pf-form-row>
          <pf-form-row :column-label="$t('Node Status')">{{ item.node_status }}</pf-form-row>
          <pf-form-row :column-label="$t('Domain')">{{ item.pf_domain }}</pf-form-row>
          <pf-form-row :column-label="$t('Profile')">{{ item.profile }}</pf-form-row>
          <pf-form-row :column-label="$t('Realm')">{{ item.realm }}</pf-form-row>
          <pf-form-row :column-label="$t('Reason')">{{ item.reason }}</pf-form-row>
          <pf-form-row :column-label="$t('Role')">{{ item.role }}</pf-form-row>
          <pf-form-row :column-label="$t('Source')">{{ item.source }}</pf-form-row>
          <pf-form-row :column-label="$t('Stripped User Name')">{{ item.stripped_user_name }}</pf-form-row>
          <pf-form-row :column-label="$t('User Name')">{{ item.user_name }}</pf-form-row>
          <pf-form-row :column-label="$t('Unique Identifier')">{{ item.uuid }}</pf-form-row>
          <pf-form-row :column-label="$t('Created at')">{{ item.created_at }}</pf-form-row>
        </b-tab>

        <b-tab title="Switch Information">
          <template slot="title">
            {{ $t('Switch Information') }}
          </template>
          <pf-form-row :column-label="$t('Switch Identifier')">{{ item.switch_id }}</pf-form-row>
          <pf-form-row :column-label="$t('Switch MAC')">{{ item.switch_mac }}</pf-form-row>
          <pf-form-row :column-label="$t('Switch IP Address')">{{ item.switch_ip_address }}</pf-form-row>
          <pf-form-row :column-label="$t('Called Station Identifier')">{{ item.called_station_id }}</pf-form-row>
          <pf-form-row :column-label="$t('Connection Type')">{{ item.connection_type }}</pf-form-row>
          <pf-form-row :column-label="$t('IfIndex')">{{ item.ifindex }}</pf-form-row>
          <pf-form-row :column-label="$t('NAS Identifier')">{{ item.nas_identifier }}</pf-form-row>
          <pf-form-row :column-label="$t('NAS IP Address')">{{ item.nas_ip_address }}</pf-form-row>
          <pf-form-row :column-label="$t('NAS Port')">{{ item.nas_port }}</pf-form-row>
          <pf-form-row :column-label="$t('NAS Port Identifer')">{{ item.nas_port_id }}</pf-form-row>
          <pf-form-row :column-label="$t('NAS Port Type')">{{ item.nas_port_type }}</pf-form-row>
          <pf-form-row :column-label="$t('RADIUS Spurce IP Address')">{{ item.radius_source_ip_address }}</pf-form-row>
          <pf-form-row :column-label="$t('Wi-Fi Network SSID')">{{ item.ssid }}</pf-form-row>
        </b-tab>

        <b-tab title="RADIUS">
          <pf-form-row :column-label="$t('Request Time')">{{ item.request_time }}</pf-form-row>
          <pf-form-row :column-label="$t('RADIUS Request')" align-v="start"><div class="text-pre my-2">{{ formatRadius(item.radius_request) }}</div></pf-form-row>
          <pf-form-row :column-label="$t('RADIUS Reply')" align-v="start"><div class="text-pre my-2">{{ formatRadius(item.radius_reply) }}</div></pf-form-row>
        </b-tab>

      </b-tabs>
    </b-card>
  </b-form>
</template>

<script>
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'RadiusLogView',
  components: {
    pfFormRow
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: String // from router
  },
  data () {
    return {
      item: {},
      tabIndex: 0,
      tabTitle: ''
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/getItem`, this.id).then(item => {
        this.item = item
      })
    },
    ifTab (set) {
      return this.$refs.tabs && set.includes(this.$refs.tabs.tabs[this.tabIndex].title)
    },
    close () {
      this.$router.push({ name: 'radiuslogs' })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    },
    formatRadius (string) {
      return string.replace(/, /g, '\n')
    }
  },
  created () {
    this.init()
  },
  mounted () {
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>

