<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">
        {{ $t('Network Devices') }}
        <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_network_devices_definition_switches_conf" />
      </h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab :title="$t('Switches')" @click="changeTab('switches')" no-body>
        <switches-search storeName="$_switches" />
      </b-tab>
      <b-tab :title="$t('Switch Groups')" @click="changeTab('switch_groups')" no-body>
        <switch-groups-list storeName="$_switch_groups" />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import pfButtonHelp from '@/components/pfButtonHelp'
import SwitchesSearch from '../switches/_components/TheSearch'
import SwitchGroupsList from './SwitchGroupsList'

export default {
  name: 'network-device-tabs',
  components: {
    pfButtonHelp,
    SwitchesSearch,
    SwitchGroupsList
  },
  props: {
    tab: {
      type: String,
      default: 'switches'
    }
  },
  computed: {
    tabIndex: {
      get () {
        return ['switches', 'switch_groups'].indexOf(this.tab)
      },
      set () {
        // noop
      }
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  }
}
</script>
