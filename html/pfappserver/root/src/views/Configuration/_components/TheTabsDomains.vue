<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Domains'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab v-for="(tab, index) in tabs" :key="index"
        :title="$t(tab.title)" @click="tabIndex = index">
        <component :is="tab.component" v-bind="('props' in tab) ? tab.props($props) : {}"/>
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import DomainsSearch from '../domains/_components/TheSearch'
import RealmsSearch from '../realms/_components/TheSearch'

const tabs = {
  domains: {
    title: 'Active Directory Domains', // i18n defer
    component: DomainsSearch,
    props: ({ autoJoinDomain }) => ({ autoJoinDomain })
  },
  realms: {
    title: 'Realms', // i18n defer
    component: RealmsSearch
  }
}

const props = {
  tab: {
    type: String,
    default: Object.keys(tabs)[0]
  },
  autoJoinDomain: {
    type: Object
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
  name: 'the-tabs-domains',
  props,
  setup
}
</script>

