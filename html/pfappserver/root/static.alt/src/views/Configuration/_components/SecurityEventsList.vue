<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Security Events'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newSecurityEvent' }">{{ $t('New Security Event') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No security events found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Security Event?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-dropdown size="sm" :text="$t('Preview')" variant="outline-primary">
            <b-dropdown-item v-for="(connectionProfile, index) in connectionProfiles" :key="index" :href="`/config/profile/${connectionProfile.id}/preview/security_events/${item.template}.html`" target="_blank">{{ connectionProfile.id }}</b-dropdown-item>
          </b-dropdown>
        </span>
      </template>
      <template slot="enabled" slot-scope="data">
        <pf-form-range-toggle
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
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationSecurityEventListConfig as config
} from '@/globals/configuration/pfConfigurationSecurityEvents'

export default {
  name: 'SecurityEventsList',
  components: {
    pfButtonDelete,
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
          this.$store.dispatch(`${this.storeName}/enableSecurityEvent`, item).then(response => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Security event <code>{desc}</code> enabled.', { service: item.desc }) })
          })
          break
        case 'N':
          this.$store.dispatch(`${this.storeName}/disableSecurityEvent`, item).then(response => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Security event <code>{desc}</code> disabled.', { service: item.desc }) })
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
