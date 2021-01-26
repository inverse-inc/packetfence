<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'PKI'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('Certificate Authorities')" @click="changeTab('pkiCas')">
        <pki-cas-list />
      </b-tab>
      <b-tab :title="$t('Templates')" @click="changeTab('pkiProfiles')">
        <pki-profiles-list />
      </b-tab>
      <b-tab :title="$t('Certificates')" @click="changeTab('pkiCerts')">
        <pki-certs-list />
      </b-tab>
      <b-tab :title="$t('Revoked Certificates')" @click="changeTab('pkiRevokedCerts')">
        <pki-revoked-certs-list />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import PkiCasList from './PkiCasList'
import PkiProfilesList from './PkiProfilesList'
import PkiCertsList from './PkiCertsList'
import PkiRevokedCertsList from './PkiRevokedCertsList'

export default {
  name: 'pkis-tabs',
  components: {
    PkiCasList,
    PkiProfilesList,
    PkiCertsList,
    PkiRevokedCertsList
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
