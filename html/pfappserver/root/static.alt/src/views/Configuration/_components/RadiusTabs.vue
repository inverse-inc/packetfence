<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'RADIUS'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('General Configuration')" @click="changeTab('radiusGeneral')">
        <radius-general-view form-store-name="formRadiusGeneral" />
      </b-tab>
      <b-tab :title="$t('EAP Profiles')" @click="changeTab('radiusEaps')">
        <radius-eap-list />
      </b-tab>
      <b-tab :title="$t('TLS Profiles')" @click="changeTab('radiusTlss')">
        <radius-tls-list />
      </b-tab>
      <b-tab :title="$t('Fast Profiles')" @click="changeTab('radiusFasts')">
        <radius-fast-list />
      </b-tab>
      <b-tab :title="$t('SSL Certificates')" @click="changeTab('radiusSsls')">
        <radius-ssl-list />
      </b-tab>
      <b-tab :title="$t('OCSP Profiles')" @click="changeTab('radiusOcsps')">
        <radius-ocsp-list />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import FormStore from '@/store/base/form'
import RadiusGeneralView from './RadiusGeneralView'
import RadiusEapList from './RadiusEapList'
import RadiusTlsList from './RadiusTlsList'
import RadiusFastList from './RadiusFastList'
import RadiusSslList from './RadiusSslList'
import RadiusOcspList from './RadiusOcspList'

export default {
  name: 'pkis-tabs',
  components: {
    RadiusGeneralView,
    RadiusEapList,
    RadiusTlsList,
    RadiusFastList,
    RadiusSslList,
    RadiusOcspList
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
  },
  beforeMount () {
    if (!this.$store.state.formRadiusGeneral) { // Register store module only once
      this.$store.registerModule('formRadiusGeneral', FormStore)
    }
  }
}
</script>
