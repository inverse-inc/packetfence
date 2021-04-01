<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Security Events') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_security_events" />
          </h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newSecurityEvent' }">{{ $t('New Security Event') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :is-loading="state.isLoading">{{ $t('No security events found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Security Event?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-dropdown size="sm" :text="$t('Preview')" variant="outline-primary">
            <b-dropdown-item v-for="(connectionProfile, index) in connectionProfiles" :key="index" :href="`/config/profile/${connectionProfile.id}/preview/security_events/${item.template}.html`" target="_blank">{{ connectionProfile.id }}</b-dropdown-item>
          </b-dropdown>
        </span>
      </template>
      <template v-slot:cell(enabled)="item">
        <toggle-status :value="item.enabled" 
          :disabled="item.id === 'defaults' || isLoading"
          :item="item" /> 
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/securityEvent'
import { ToggleStatus } from '@/views/Configuration/securityEvents/_components/'

export default {
  name: 'security-events-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable,
    ToggleStatus
  },
  data () {
    return {
      config: config(this),
      connectionProfiles: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_security_events/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneSecurityEvent', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_security_events/deleteSecurityEvent', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  },
  created () {
    this.$store.dispatch(`$_connection_profiles/all`).then(data => {
      this.connectionProfiles = data
    })
  }
}
</script>
