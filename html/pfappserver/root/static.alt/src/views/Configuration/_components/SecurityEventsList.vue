<template>
  <b-card no-body>
    <pf-config-list
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
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No security events found') }}</pf-empty-table>
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
      <template v-slot:cell(enabled)="data">
        <pf-form-range-toggle v-if="data.id === 'defaults'"
          v-model="data.enabled"
          :values="{ checked: 'Y', unchecked: 'N' }"
          :icons="{ checked: 'lock', unchecked: 'lock' }"
          :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
          disabled
        >{{ (data.enabled === 'Y') ? 'ON' : 'OFF' }}</pf-form-range-toggle>
        <pf-form-range-toggle v-else
          v-model="data.enabled"
          :values="{ checked: 'Y', unchecked: 'N' }"
          :icons="{ checked: 'check', unchecked: 'times' }"
          :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
          :disabled="isLoading"
          @input="toggle(data, $event)"
          @click.stop.prevent
        >{{ (data.enabled === 'Y') ? 'ON' : 'OFF' }}</pf-form-range-toggle>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationSecurityEventListConfig as config
} from '@/globals/configuration/pfConfigurationSecurityEvents'

export default {
  name: 'security-events-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable,
    pfFormRangeToggle
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      config: config(this),
      connectionProfiles: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneSecurityEvent', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteSecurityEvent`, item.id).then(response => {
        this.$router.go() // reload
      })
    },
    toggle (item, event) {
      switch (event) {
        case 'Y':
          this.$store.dispatch(`${this.storeName}/enableSecurityEvent`, { quiet: true, ...item }).then(response => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Security event {desc} enabled.', { desc: this.$strong(item.desc) }) })
          }).catch(err => {
            const { response: { data: { message: errMsg } = {} } = {} } = err
            let message = this.$i18n.t('Security event {desc} was not enabled', { desc: this.$strong(item.desc) })
            if (errMsg) message += ` (${errMsg})`
            this.$store.dispatch('notification/danger', { message })
          })
          break
        case 'N':
          this.$store.dispatch(`${this.storeName}/disableSecurityEvent`, { quiet: true, ...item }).then(response => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Security event {desc} disabled.', { desc: this.$strong(item.desc) }) })
          }).catch(err => {
            const { response: { data: { message: errMsg } = {} } = {} } = err
            let message = this.$i18n.t('Security event {desc} was not disabled', { desc: this.$strong(item.desc) })
            if (errMsg) message += ` (${errMsg})`
            this.$store.dispatch('notification/danger', { message })
          })
          break
      }
    }
  },
  created () {
    this.$store.dispatch(`$_connection_profiles/all`).then(data => {
      this.connectionProfiles = data
    })
  }
}
</script>
