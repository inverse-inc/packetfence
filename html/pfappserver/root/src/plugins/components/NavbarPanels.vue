<template>
  <div>
    <div v-for="plugin in opened" :key="plugin.id" v-show="shown === plugin.id" class="plugin-navbar-panel border-bottom mb-3">
      <bundle-mount :plugin-id="plugin.id" kind="navbar-panel" />
    </div>
  </div>
</template>
<script>
/**
 * The panels of the bundle plugins with a "navbar-panel" mount, under the
 * navbar. A panel is mounted when it is first opened, then kept (hidden) so
 * that the plugin keeps its state; one is shown at a time.
 *
 * They slide down and up like the documentation viewer: the "animation" event
 * gives the class for the container of the page (App.vue), the panel closing
 * stays shown until it has slid up.
 */
const SLIDE_OUT_MS = 150 // plugin-panel-leave
import BundleMount from './BundleMount'
import { navbarPlugins, openPanel } from '..'

export default {
  name: 'plugin-navbar-panels',
  components: { BundleMount },
  data: () => ({ mounted: [], shown: null, leaving: null }),
  computed: {
    open: () => openPanel(),
    opened () {
      return navbarPlugins().filter(plugin => this.mounted.includes(plugin.id))
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
}

// the slide of the documentation viewer (AppDocumentation)
.plugin-panel-enter {
  animation: plugin-panel-slide-in 0.3s cubic-bezier(0.250, 0.460, 0.450, 0.940) both;
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
