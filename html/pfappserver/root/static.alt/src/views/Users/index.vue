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
          name: this.$i18n.t('Search'),
          path: '/users/search',
          saveSearchNamespace: 'users'
        },
        {
          name: this.$i18n.t('Create'),
          path: '/users/create',
          can: 'create users'
        },
        {
          name: this.$i18n.t('Import'),
          path: '/users/import',
          can: 'create users'
        }
      ]
    }
  }
}
</script>
