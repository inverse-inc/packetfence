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
  name: 'Tests',
  components: {
    pfSidebar
  },
  data () {
    return {
      sections: [
        {
          name: this.$i18n.t('Test 001'),
          path: '/tests/test001'
        }
      ]
    }
  }
}
</script>
