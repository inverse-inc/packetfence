<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('DHCP Option 82 Log Entry')}} <strong v-text="id"></strong></h4>
      </b-card-header>
      <pf-form-row :column-label="$t('MAC Address')">{{ item.mac }}</pf-form-row>
      <pf-form-row :column-label="$t('Circuit ID String')">{{ item.circuit_id_string }}</pf-form-row>
      <pf-form-row :column-label="$t('Host')">{{ item.host }}</pf-form-row>
      <pf-form-row :column-label="$t('Module')">{{ item.module }}</pf-form-row>
      <pf-form-row :column-label="$t('Option82 Switch')">{{ item.option82_switch }}</pf-form-row>
      <pf-form-row :column-label="$t('Port')">{{ item.port }}</pf-form-row>
      <pf-form-row :column-label="$t('Switch ID')">{{ item.switch_id }}</pf-form-row>
      <pf-form-row :column-label="$t('DHCP Option 82 VLAN')">{{ item.vlan }}</pf-form-row>
      <pf-form-row :column-label="$t('Created At')">{{ item.created_at }}</pf-form-row>
    </b-card>
  </b-form>
</template>

<script>
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'DhcpOption82LogView',
  components: {
    pfFormRow
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    mac: String // from router
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
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/getItem`, this.mac).then(item => {
        this.item = item
      })
    },
    ifTab (set) {
      return this.$refs.tabs && set.includes(this.$refs.tabs.tabs[this.tabIndex].title)
    },
    close () {
      this.$router.push({ name: 'dhcpoption82s' })
    }
  },
  created () {
    this.init()
  },
  watch: {
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
