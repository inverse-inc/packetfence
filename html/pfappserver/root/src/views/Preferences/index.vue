<template>
        <b-row>
            <pf-sidebar v-model="sections"></pf-sidebar>
            <b-col cols="12" md="9" xl="10" class="py-3">
                <transition name="slide-bottom">
                    <router-view></router-view>
                </transition>
            </b-col>
        </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'

export default {
  name: 'Preferences',
  components: {
    pfSidebar
  },
  computed: {
    sections () {
      return [
        {
          name: this.$i18n.t('Settings'),
          path: '/preferences/settings'
        },
        {
          name: this.$i18n.t('Permissions'),
          path: '/preferences/permissions'
        }
      ]
    }
  }
}
</script>
