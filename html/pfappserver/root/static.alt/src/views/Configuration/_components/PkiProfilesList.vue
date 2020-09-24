<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">{{ $t('Templates') }}</h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-dropdown :text="$t('New Template')" variant="outline-primary" :disabled="cas.length === 0">
          <b-dropdown-header>{{ $t('Choose Certificate Authority') }}</b-dropdown-header>
          <b-dropdown-item v-for="ca in sortedCas" :key="ca.ID" :to="{ name: 'newPkiProfile', params: { ca_id: ca.ID } }">{{ ca.cn }}</b-dropdown-item>
        </b-dropdown>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading" @start="init" @restart="init"></pf-button-service>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No profiles found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(ca_name)="item">
        <router-link :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1 text-nowrap" :to="{ name: 'newPkiCert', params: { profile_id: item.ID } }">{{ $t('New Certificate') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  config
} from '../_config/pki/profile'

export default {
  name: 'pki-profiles-list',
  components: {
    pfButtonService,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    cas () {
      return this.$store.getters['$_pkis/cas'] || []
    },
    sortedCas () {
      return Array.prototype.slice.call(this.cas).sort((a, b) => a.cn.localeCompare(b.cn)) // sort cas by 'cn'
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allCas')
    },
    clone (item) {
      this.$router.push({ name: 'clonePkiProfile', params: { id: item.ID } })
    }
  },
  created () {
    this.init()
  }
}
</script>
