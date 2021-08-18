<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'PKI'"></h4>
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
import PkiCasSearch from '../pki/cas/_components/TheSearch'
import PkiProfilesSearch from '../pki/profiles/_components/TheSearch'
import PkiCertsSearch from '../pki/certs/_components/TheSearch'
import PkiRevokedCertsSearch from '../pki/revokedCerts/_components/TheSearch'

const tabs = {
  pkiCas: {
    title: 'Certificate Authorities', // i18n defer
    component: PkiCasSearch
  },
  pkiProfiles: {
    title: 'Templates', // i18n defer
    component: PkiProfilesSearch
  },
  pkiCerts: {
    title: 'Certificates', // i18n defer
    component: PkiCertsSearch
  },
  pkiRevokedCerts: {
    title: 'Revoked Certificates', // i18n defer
    component: PkiRevokedCertsSearch
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
  name: 'the-tabs-pkis',
  props,
  setup
}
</script>
