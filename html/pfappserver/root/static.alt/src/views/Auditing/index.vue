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
  name: 'Auditing',
  components: {
    pfSidebar
  },
  data () {
    return {
      sections: [
        {
          name: 'RADIUS Audit Logs',
          path: '/auditing/radiuslogs/search',
          saveSearchNamespace: 'radiuslogs'
        },
        {
          name: 'Option82',
          path: '/auditing/dhcpoption82s/search',
          saveSearchNamespace: 'dhcpoption82s'
        }
      ]
    }
  }
}
</script>
