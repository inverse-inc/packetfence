<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header>
          <b-row class="align-items-center px-0" no-gutters>
            <b-col cols="auto" class="mr-auto">
              <h4 class="d-inline mb-0" v-t="'DHCPv6 Fingerprints'"></h4>
              <b-badge class="ml-2" variant="secondary" v-t="scope"></b-badge>
            </b-col>
            <b-col cols="auto" align="right" class="flex-grow-0">
              <b-button-group>
                <b-button v-t="'All'" :variant="(scope === 'all') ? 'primary' : 'outline-secondary'" @click="changeScope('all')"></b-button>
                <b-button v-t="'Local'" :variant="(scope === 'local') ? 'primary' : 'outline-secondary'" @click="changeScope('local')"></b-button>
                <b-button v-t="'Upstream'" :variant="(scope === 'upstream') ? 'primary' : 'outline-secondary'" @click="changeScope('upstream')"></b-button>
              </b-button-group>
            </b-col>
          </b-row>
        </b-card-header>
      </template>
      <template slot="buttonAdd" v-if="scope === 'local'">
        <b-button variant="outline-primary" :to="{ name: 'newFingerbankDhcpv6Fingerprint', params: { scope: 'local' } }">{{ $t('Add DHCPv6 Fingerprint') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No {scope} DHCPv6 fingerprints found', { scope: ((scope !== 'all') ? scope : '') }) }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable && scope === 'local'" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete DHCPv6 Fingerprint?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFingerbankScore from '@/components/pfFingerbankScore'

import {
  pfConfigurationFingerbankDhcpv6FingerprintsListConfig as config
} from '@/globals/configuration/pfConfigurationFingerbank'

export default {
  name: 'FingerbankDhcpv6FingerprintsList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable,
    pfFingerbankScore
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    scope: {
      type: String,
      default: 'all',
      required: false
    }
  },
  data () {
    return {
      data: [],
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneFingerbankDhcpv6Fingerprint', params: { scope: this.scope, id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteDhcpv6Fingerprint`, item.id).then(response => {
        this.$router.go() // reload
      })
    },
    changeScope (scope) {
      this.scope = scope
    }
  },
  created () {
    this.$store.dispatch(`${this.storeName}/dhcpv6Fingerprints`).then(data => {
      this.data = data
    })
  },
  watch: {
    scope: {
      handler: function (a, b) {
        if (a !== b) {
          this.config = config(this) // reset config
        }
      }
    }
  }
}
</script>
