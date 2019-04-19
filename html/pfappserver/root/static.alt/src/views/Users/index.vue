<template>
  <b-row>
    <pf-sidebar v-model="sections"></pf-sidebar>
    <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
      <transition name="slide-bottom">
        <router-view></router-view>
      </transition>
    </b-col>
  </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'

export default {
  name: 'Users',
  components: {
    pfSidebar
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      sections: [
        {
          name: 'Search',
          path: '/users/search',
          saveSearchNamespace: 'users'
        },
        {
          name: 'Create',
          path: '/users/create',
          can: 'create users'
        },
        {
          name: 'Import',
          path: '/users/import',
          can: 'create users'
        },
        {
          name: 'Standard Searches',
          items: [
            {
              name: 'Open Security Events',
              path: 'search/open_security_events'
            },
            {
              name: 'Closed Security Events',
              path: 'search/closed_security_events'
            }
          ]
        }
      ]
    }
  }
}
</script>
