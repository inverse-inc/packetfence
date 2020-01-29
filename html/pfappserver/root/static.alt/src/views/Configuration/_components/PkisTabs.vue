<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'PKI'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('Certificate Authorities')" @click="changeTab('pkiCas')">
        <pki-cas-list />
      </b-tab>
      <b-tab :title="$t('All Profiles')" @click="changeTab('pkiProfiles')">
        <pki-profiles-list />
      </b-tab>
      <b-tab :title="$t('All Certificates')" @click="changeTab('pkiCerts')">
        <pki-certs-list />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import FormStore from '@/store/base/form'
import PkiCasList from './PkiCasList'
import PkiProfilesList from './PkiProfilesList'
import PkiCertsList from './PkiCertsList'

export default {
  name: 'pkis-tabs',
  components: {
    PkiCasList,
    PkiProfilesList,
    PkiCertsList
  },
  props: {
    tab: {
      type: String,
      default: 'pkiCas'
    }
  },
  computed: {
    tabIndex () {
      return ['pkiCas', 'pkiProfiles', 'pkiCerts'].indexOf(this.tab)
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  }
}
</script>
