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

export default {
  name: 'Status',
  components: {
    pfSidebar
  },
  data () {
    return {
      sections: [
        {
          name: this.$i18n.t('Status'),
          items: [
            {
              name: this.$i18n.t('Dashboard'),
              path: '/status/dashboard'
            },
            {
              name: this.$i18n.t('Services'),
              path: '/status/services',
              can: 'read services'
            },
            {
              name: this.$i18n.t('Local Queue'),
              path: '/status/queue',
              can: 'read services'
            }
          ]
        }
      ]
    }
  }
}
</script>
