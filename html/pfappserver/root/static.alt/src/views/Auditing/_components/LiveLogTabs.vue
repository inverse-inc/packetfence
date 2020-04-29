<template>
  <b-tabs ref="tabs" v-model="tabIndex" card>
    <b-tab v-for="(tab, index) in tabs" :key="tab.session_id" :title="tab.name" no-body
      @click="go(index)"
    >
      <template v-slot:title>
        <span v-if="index > 0 && isLoading" class="float-right text-secondary ml-2">
          <icon name="circle-notch" scale="1.5" spin></icon>
        </span>
        <span v-else-if="index > 0" class="float-right text-secondary ml-2" @click.prevent.stop="destroy(tab.session_id)"
          v-b-tooltip.hover.top.d300 :title="$t('Close Session')"
        >
          <icon name="times" scale="1.5"></icon>
        </span>
        {{ $t(tab.name) }}
      </template>
      <!-- TABS ARE ONLY VISUAL, NOTHING HERE... -->
    </b-tab>
  </b-tabs>
</template>

<script>
export default {
  name: 'live-log-tabs',
  computed: {
    isLoading () {
      return this.$store.getters['$_live_logs/isLoading']
    },
    tabIndex () {
      const { params: { id } = {} } = this.$route
      if (id) {
        let sessionIndex = this.sessions.findIndex(s => {
          return s.session_id === id
        })
        if (sessionIndex > -1) {
          return sessionIndex + 1
        }
      }
      return 0
    },
    tabs () {
      return [
        { name: this.$i18n.t('Create Session'), route: { name: 'live_logs' } },
        ...this.sessions.map(session => {
          const { name, session_id } = session
          return {
            session_id,
            name,
            route: { name: 'live_log', params: { id: session_id } }
          }
        })
      ]
    },
    sessions () {
      return this.$store.getters['$_live_logs/sessions']
    }
  },
  methods: {
    go (tabIndex) {
      this.$router.push(this.tabs[tabIndex].route)
    },
    destroy (session_id) {
      this.$store.dispatch('$_live_logs/destroySession', session_id).then(() => {
        const { params: { id } = {} } = this.$route
        if (session_id === id) { // tab is currently selected
          this.$router.push({ name: 'live_logs' })
        }
      })
    }
  }
}
</script>
