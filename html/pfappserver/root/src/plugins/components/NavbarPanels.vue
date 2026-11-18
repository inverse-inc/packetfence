<template>
  <div>
    <div v-for="plugin in opened" :key="plugin.id" v-show="open === plugin.id" class="plugin-navbar-panel border-bottom mb-3">
      <bundle-mount :plugin-id="plugin.id" kind="navbar-panel" />
    </div>
  </div>
</template>
<script>
/**
 * The panels of the bundle plugins with a "navbar-panel" mount, under the
 * navbar. A panel is mounted when it is first opened, then kept (hidden) so
 * that the plugin keeps its state; one is shown at a time.
 */
import BundleMount from './BundleMount'
import { navbarPlugins, openPanel } from '..'

export default {
  name: 'plugin-navbar-panels',
  components: { BundleMount },
  data: () => ({ mounted: [] }),
  computed: {
    open: () => openPanel(),
    opened () {
      return navbarPlugins().filter(plugin => this.mounted.includes(plugin.id))
    }
  },
  watch: {
    open: {
      handler (id) {
        if (id && !this.mounted.includes(id))
          this.mounted.push(id)
      },
      immediate: true
    }
  }
}
</script>
<style lang="scss">
.plugin-navbar-panel {
  height: 50vh;
  overflow: auto;
}
</style>
