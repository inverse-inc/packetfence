<template>
        <b-row>
            <pf-sidebar v-model="sections">
                <pf-saved-search :storeName="storeName" :routeName="this.$options.name.toLowerCase()"/>
            </pf-sidebar>
            <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
                <transition name="slide-bottom">
                    <router-view></router-view>
                </transition>
            </b-col>
        </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'
import pfSavedSearch from '@/components/pfSavedSearch'

export default {
  name: 'Users',
  components: {
    pfSidebar,
    pfSavedSearch
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
          path: '/users/search'
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
              path: 'search/opensecurity_events'
            },
            {
              name: 'Closed Security Events',
              path: 'search/closedsecurity_events'
            }
          ]
        }
      ]
    }
  }
}
</script>
