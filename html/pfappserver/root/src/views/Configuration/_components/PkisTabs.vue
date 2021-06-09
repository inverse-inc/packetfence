<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'PKI'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab :title="$t('Certificate Authorities')" @click="changeTab('pkiCas')">
        <pki-cas-search />
      </b-tab>
      <b-tab :title="$t('Templates')" @click="changeTab('pkiProfiles')">
        <pki-profiles-search />
      </b-tab>
      <b-tab :title="$t('Certificates')" @click="changeTab('pkiCerts')">
        <pki-certs-search />
      </b-tab>
      <b-tab :title="$t('Revoked Certificates')" @click="changeTab('pkiRevokedCerts')">
        <pki-revoked-certs-search />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import PkiCasSearch from '../pki/cas/_components/TheSearch'
import PkiProfilesSearch from '../pki/profiles/_components/TheSearch'
import PkiCertsSearch from '../pki/certs/_components/TheSearch'
import PkiRevokedCertsSearch from '../pki/revokedCerts/_components/TheSearch'

export default {
  name: 'pkis-tabs',
  components: {
    PkiCasSearch,
    PkiProfilesSearch,
    PkiCertsSearch,
    PkiRevokedCertsSearch
  },
  props: {
    tab: {
      type: String,
      default: 'pkiCas'
    }
  },
  computed: {
    tabIndex: {
      get () {
        return ['pkiCas', 'pkiProfiles', 'pkiCerts', 'pkiRevokedCerts'].indexOf(this.tab)
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
