<template>
  <b-navbar-nav v-if="plugins.length">
    <b-nav-item v-for="plugin in plugins" :key="plugin.id" @click="toggle(plugin.id)" :active="open === plugin.id"
      v-b-tooltip.hover.bottom.d300 :title="title(plugin)">
      <icon :name="plugin.manifest.bundle.navbar.icon" />
    </b-nav-item>
  </b-navbar-nav>
</template>
<script>
/**
 * The navbar buttons of the bundle plugins with a "navbar-panel" mount: each
 * opens its panel (NavbarPanels), one at a time.
 */
import { navbarPlugins, openPanel, togglePanel, translate } from '..'

export default {
  name: 'plugin-navbar-items',
  computed: {
    plugins: () => navbarPlugins(),
    open: () => openPanel()
  },
  methods: {
    title: plugin => translate(plugin.manifest.title),
    toggle (id) {
      togglePanel(id)
      this.$emit('toggle', openPanel())
    }
  }
}
</script>
