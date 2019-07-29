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
              <h4 class="d-inline mb-0" v-t="'DHCP Agents'"></h4>
            </b-col>
          </b-row>
        </b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newFingerbankUserAgent' }">{{ $t('New DHCP Agent') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No local DHCP fingerprints found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete DHCP Agent?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template slot="score" slot-scope="data">
        <pf-fingerbank-score :score="data.score"></pf-fingerbank-score>
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
  pfConfigurationFingerbankUserAgentsListConfig as config
} from '@/globals/configuration/pfConfigurationFingerbank'

export default {
  name: 'fingerbank-user-agents-list',
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
      this.$router.push({ name: 'cloneFingerbankUserAgent', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteUserAgent`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  },
  created () {
    this.$store.dispatch(`${this.storeName}/userAgents`).then(data => {
      this.data = data
    })
  }
}
</script>
