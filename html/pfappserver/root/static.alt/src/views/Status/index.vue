<template>
        <b-row>
            <pf-sidebar v-model="sections"></pf-sidebar>
            <b-col cols="12" md="9" xl="10">
                <router-view></router-view>
            </b-col>
        </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'
import store from './_store'

export default {
  name: 'Status',
  components: {
    pfSidebar
  },
  data () {
    return {
      sections: [
        {
          name: 'Status',
          items: [
            {
              name: 'Dashboard',
              path: '/status/dashboard'
            },
            {
              name: 'Services',
              path: '/status/services',
              can: 'access services'
            },
            {
              name: 'Reports',
              path: '/status/reports',
              can: 'access reports'
            }
          ]
        }
      ]
    }
  },
  created () {
    // Register store module only once
    if (!this.$store.state.$_status) {
      this.$store.registerModule('$_status', store)
    }
  }
}
</script>
