<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'RADIUS'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab :title="$t('General Configuration')" @click="changeTab('radiusGeneral')">
        <radius-general-view />
      </b-tab>
      <b-tab :title="$t('EAP Profiles')" @click="changeTab('radiusEaps')">
        <radius-eap-search />
      </b-tab>
      <b-tab :title="$t('TLS Profiles')" @click="changeTab('radiusTlss')">
        <radius-tls-search />
      </b-tab>
      <b-tab :title="$t('Fast Profiles')" @click="changeTab('radiusFasts')">
        <radius-fast-search />
      </b-tab>
      <b-tab :title="$t('SSL Certificates')" @click="changeTab('radiusSsls')">
        <radius-ssl-search />
      </b-tab>
      <b-tab :title="$t('OCSP Profiles')" @click="changeTab('radiusOcsps')">
        <radius-ocsp-search />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import RadiusGeneralView from '../radius/general/_components/TheView'
import RadiusEapSearch from '../radius/eap/_components/TheSearch'
import RadiusTlsSearch from '../radius/tls/_components/TheSearch'
import RadiusFastSearch from '../radius/fast/_components/TheSearch'
import RadiusSslSearch from '../radius/ssl/_components/TheSearch'
import RadiusOcspSearch from '../radius/ocsp/_components/TheSearch'

export default {
  name: 'pkis-tabs',
  components: {
    RadiusGeneralView,
    RadiusEapSearch,
    RadiusTlsSearch,
    RadiusFastSearch,
    RadiusSslSearch,
    RadiusOcspSearch
  },
  props: {
    tab: {
      type: String,
      default: 'radiusGeneral'
    }
  },
  computed: {
    tabIndex: {
      get () {
        return ['radiusGeneral', 'radiusEaps', 'radiusTlss', 'radiusFasts', 'radiusSsls', 'radiusOcsps'].indexOf(this.tab)
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
