<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'RADIUS'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab v-for="(tab, index) in tabs" :key="index"
        :title="$t(tab.title)" @click="tabIndex = index">
        <component :is="tab.component" />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import RadiusGeneralView from '../radius/general/_components/TheView'
import RadiusEapSearch from '../radius/eap/_components/TheSearch'
import RadiusTlsSearch from '../radius/tls/_components/TheSearch'
import RadiusFastSearch from '../radius/fast/_components/TheSearch'
import RadiusTeapSearch from '../radius/teap/_components/TheSearch'
import RadiusSslSearch from '../radius/ssl/_components/TheSearch'
import RadiusOcspSearch from '../radius/ocsp/_components/TheSearch'
['radiusGeneral', 'radiusEaps', 'radiusTlss', 'radiusFasts', 'radiusTeaps', 'radiusSsls', 'radiusOcsps']
const tabs = {
  radiusGeneral: {
    title: 'General Configuration', // i18n defer
    component: RadiusGeneralView
  },
  radiusEaps: {
    title: 'EAP Profiles', // i18n defer
    component: RadiusEapSearch
  },
  radiusTlss: {
    title: 'TLS Profiles', // i18n defer
    component: RadiusTlsSearch
  },
  radiusFasts: {
    title: 'Fast Profiles', // i18n defer
    component: RadiusFastSearch
  },
  radiusTeaps: {
    title: 'TEAP Profiles', // i18n defer
    component: RadiusTeapSearch
  },
  radiusSsls: {
    title: 'PKI SSL Certificates', // i18n defer
    component: RadiusSslSearch
  },
  radiusOcsps: {
    title: 'OCSP Profile', // i18n defer
    component: RadiusOcspSearch
  }
}

const props = {
  tab: {
    type: String,
    default: Object.keys(tabs)[0]
  }
}

import { customRef, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    tab
  } = toRefs(props)

  const { root: { $router } = {} } = context

  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
      return Object.keys(tabs).indexOf(tab.value)
    },
    set(newValue) {
      $router.push({ name: Object.keys(tabs)[newValue] })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
      trigger()
    }
  }))

  return {
    tabs,
    tabIndex
  }
}

// @vue/component
export default {
  name: 'the-tabs-radius',
  props,
  setup
}
</script>
