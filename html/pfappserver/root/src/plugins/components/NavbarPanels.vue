<template>
  <div>
    <div v-for="panel in opened" :key="panel.id" v-show="shown === panel.id" class="plugin-navbar-panel border-bottom mb-3">
      <component v-if="panel.component" :is="panel.component" />
      <bundle-mount v-else :plugin-id="panel.id" kind="navbar-panel" />
    </div>
  </div>
</template>
<script>
/**
 * The panels under the navbar: the ones of core (the logs) and of the bundle
 * plugins with a "navbar-panel" mount. A panel is mounted when it is first opened, then kept (hidden) so
 * that the plugin keeps its state; one is shown at a time.
 *
 * They slide down and up like the documentation viewer: the "animation" event
 * gives the class for the container of the page (App.vue), the panel closing
 * stays shown until it has slid up.
 */
const SLIDE_OUT_MS = 150 // plugin-panel-leave
import BundleMount from './BundleMount'
import { HISTORICAL_LOGS_PANEL, LIVE_LOGS_PANEL, navbarPlugins, openPanel } from '..'

// the panels of core: the logs (their buttons are in App.vue)
const CORE_PANELS = [
  { id: LIVE_LOGS_PANEL, component: () => import(/* webpackChunkName: "LiveLogs" */ '@/views/LiveLogs/_components/ThePanel') },
  { id: HISTORICAL_LOGS_PANEL, component: () => import(/* webpackChunkName: "HistoricalLogs" */ '@/views/HistoricalLogs/_components/ThePanel') }
]

export default {
  name: 'plugin-navbar-panels',
  components: { BundleMount },
  data: () => ({ mounted: [], shown: null, leaving: null }),
  computed: {
    open: () => openPanel(),
    opened () {
      return [...CORE_PANELS, ...navbarPlugins()].filter(panel => this.mounted.includes(panel.id))
    }
  },
  watch: {
    open: {
      handler (id, previous) {
        clearTimeout(this.leaving)
        if (id) {
          if (!this.mounted.includes(id))
            this.mounted.push(id)
          if (!this.shown || !previous) // not from one panel to another
            this.$emit('animation', 'plugin-panel-enter')
          this.shown = id
        }
        else if (this.shown) {
          this.$emit('animation', 'plugin-panel-leave')
          this.leaving = setTimeout(() => {
            this.shown = null
            this.$emit('animation', null)
          }, SLIDE_OUT_MS)
        }
      },
      immediate: true
    }
  }
}
</script>
<style lang="scss">
$plugin-panel-height: 50vh;

.plugin-navbar-panel {
  height: $plugin-panel-height;
  overflow: auto;
  // the logs fill the panel, not the window
  .live-logs-page,
  .historical-logs-page {
    height: 100%;
    margin-left: 0;
    margin-right: 0;
  }
}

// the slide of the documentation viewer (AppDocumentation)
// "backwards", not "both": once in, the container keeps no transform, which
// would make it the containing block of the position: fixed elements of the
// panels (the menus that must not be clipped by the panel)
.plugin-panel-enter {
  animation: plugin-panel-slide-in 0.3s cubic-bezier(0.250, 0.460, 0.450, 0.940) backwards;
}
.plugin-panel-leave {
  animation: plugin-panel-slide-out 0.15s cubic-bezier(0.250, 0.460, 0.450, 0.940) both;
}
@keyframes plugin-panel-slide-in {
  0% { transform: translateY(-#{$plugin-panel-height}); }
  100% { transform: translateY(0); }
}
@keyframes plugin-panel-slide-out {
  0% { transform: translateY(0); }
  100% { transform: translateY(-#{$plugin-panel-height}); }
}
</style>
