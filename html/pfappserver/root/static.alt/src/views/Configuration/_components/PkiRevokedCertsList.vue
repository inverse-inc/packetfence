<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">{{ $t('Revoked Certificates') }}</h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading" @start="init" @restart="init"></pf-button-service>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No revoked certificates found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(ca_name)="item">
        <router-link :to="{ name: 'pkiCa', params: { id: item.ca_id } }">{{ item.ca_name }}</router-link>
      </template>
      <template v-slot:cell(profile_name)="item">
        <router-link :to="{ name: 'pkiProfile', params: { id: item.profile_id } }">{{ item.profile_name }}</router-link>
      </template>
      <template v-slot:cell(crl_reason)="item">
        {{ revokeReasons.find(reason => ~~reason.value === ~~item.crl_reason).text }}
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
} from '../_config/pki/revokedCert'
import {
  revokeReasons
} from '../_config/pki/'

export default {
  name: 'pki-revoked-certs-list',
  components: {
    pfButtonService,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      revokeReasons,
      profiles: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isRevokedCertLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allProfiles').then(profiles => {
        this.profiles = (profiles || []).sort((a, b) => { // sort profiles
          return (a.ca_name === b.ca_name)
            ? a.name.localeCompare(b.name)
            : a.ca_name.localeCompare(b.ca_name)
        })
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
