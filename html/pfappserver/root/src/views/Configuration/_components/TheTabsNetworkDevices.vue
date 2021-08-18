<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">
        {{ $t('Network Devices') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_network_devices_definition_switches_conf" />
      </h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab :title="$t('Switches')" @click="changeTab('switches')" no-body>
        <switches-search />
      </b-tab>
      <b-tab :title="$t('Switch Groups')" @click="changeTab('switch_groups')" no-body>
        <switch-groups-search />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import {
  BaseButtonHelp
} from '@/components/new/'
import SwitchesSearch from '../switches/_components/TheSearch'
import SwitchGroupsSearch from '../switchGroups/_components/TheSearch'

export default {
  name: 'network-device-tabs',
  components: {
    BaseButtonHelp,
    SwitchesSearch,
    SwitchGroupsSearch
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
