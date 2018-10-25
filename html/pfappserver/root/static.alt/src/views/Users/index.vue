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
import pfMixinSavedSearch from '@/components/pfMixinSavedSearch'

export default {
  name: 'Users',
  mixins: [
    pfMixinSavedSearch
  ],
  components: {
    pfSidebar,
    'pf-saved-search': pfMixinSavedSearch
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
              name: 'Open Violations',
              path: 'search/openviolations'
            },
            {
              name: 'Closed Violations',
              path: 'search/closedviolations'
            }
          ]
        }
      ]
    }
  }
}
</script>
