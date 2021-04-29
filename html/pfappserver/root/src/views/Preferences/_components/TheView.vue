<template>
  <base-view>
    <template v-slot:header>
      <h4 class="mb-0" v-html="'Preferences'" />
    </template>
    <b-tabs v-model="tabIndex" card>
      <tab-settings />
      <tab-permissions />
    </b-tabs>
  </base-view>
</template>
<script>
import BaseView from '@/components/new/BaseView'
import TabSettings from './TabSettings'
import TabPermissions from './TabPermissions'

const components = {
  BaseView,
  TabSettings,
  TabPermissions
}

import { customRef, toRefs } from '@vue/composition-api'

const props = {
  tab: {
    type: String,
    default: 'settings'
  }
}

const TABS = ['settings', 'permissions']

const setup = (props, context) => {

  const {
    tab
  } = toRefs(props)

  const { root: { $router } = {} } = context

  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
      return TABS.indexOf(tab.value)
    },
    set(newValue) {
      const tab = TABS[newValue]
      $router.push({ path: `/preferences/${tab}`, params: { tab } })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
      trigger()
    }
  }))

  return {
    tabIndex
  }
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>