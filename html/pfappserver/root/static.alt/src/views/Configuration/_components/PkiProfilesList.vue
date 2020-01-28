<template>
  <b-card>
    <h4 class="mb-3">{{ $t('Profiles') }}</h4>
    <b-row align-h="end" align-v="start" class="mb-3">
      <b-col>
        <b-dropdown :text="$t('New Profile')" variant="outline-primary" :disabled="cas.length === 0">
          <b-dropdown-header>{{ $t('Choose Certificate Authority') }}</b-dropdown-header>
          <b-dropdown-item v-for="ca in cas" :key="ca.ID" :to="{ name: 'newPkiProfile', params: { ca_id: ca.ID } }">{{ ca.cn }}</b-dropdown-item>
        </b-dropdown>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading" @start="init" @restart="init"></pf-button-service>
      </b-col>
    </b-row>
    <b-table
      :items="profiles"
      :fields="columns"
      @row-clicked="onRowClick"
      hover
      striped
    >
      <template v-slot:empty>
        <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new Profile.')">{{ $t('No profiles defined') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="{ item }">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" :to="{ name: 'newPkiCert', params: { profile_id: item.ID } }">{{ $t('New Certificate') }}</b-button>
        </span>
      </template>
    </b-table>
  </b-card>
</template>

<script>
import pfButtonService from '@/components/pfButtonService'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  columns
} from '../_config/pki/profile'

export default {
  name: 'pki-profiles-list',
  components: {
    pfButtonService,
    pfEmptyTable
  },
  data () {
    return {
      columns, // ../_config/pki/profile
      cas: [],
      profiles: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isProfileLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allCas').then(cas => {
        this.cas = cas.sort((a, b) => { // sort cas
          return a.cn.localeCompare(b.cn)
        })
      })
      this.$store.dispatch('$_pkis/allProfiles').then(profiles => {
        this.profiles = profiles
      })
    },
    clone (item) {
      this.$router.push({ name: 'clonePkiProfile', params: { id: item.ID } })
    },
    onRowClick (item) {
      this.$router.push({ name: 'pkiProfile', params: { id: item.ID } })
    }
  },
  created () {
    this.init()
  }
}
</script>
