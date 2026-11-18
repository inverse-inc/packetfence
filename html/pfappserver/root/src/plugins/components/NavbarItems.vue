<template>
  <b-navbar-nav v-if="plugins.length">
    <b-nav-item v-for="plugin in plugins" :key="plugin.id" @click="toggle(plugin.id)" :active="open === plugin.id"
      v-b-tooltip.hover.bottom.d300 :title="title(plugin)">
      <span class="plugin-navbar-item">
        <icon :name="plugin.manifest.bundle.navbar.icon" />
        <span v-if="badge(plugin.id)" class="plugin-navbar-badge" />
      </span>
    </b-nav-item>
  </b-navbar-nav>
</template>
<script>
/**
 * The navbar buttons of the bundle plugins with a "navbar-panel" mount: each
 * opens its panel (NavbarPanels), one at a time.
 */
import { navbarPlugins, openPanel, panelBadge, togglePanel, translate } from '..'

export default {
  name: 'plugin-navbar-items',
  computed: {
    plugins: () => navbarPlugins(),
    open: () => openPanel()
  },
  methods: {
    title: plugin => translate(plugin.manifest.title),
    badge: id => panelBadge(id),
    toggle (id) {
      togglePanel(id)
      this.$emit('toggle', openPanel())
    }
  }
}
</script>
<style lang="scss">
// the badge of a plugin button (host.panel.setBadge): a red dot top-right
.plugin-navbar-item {
  position: relative;
  display: inline-block;
  .plugin-navbar-badge {
    position: absolute;
    top: -.15rem;
    right: -.3rem;
    width: .5rem;
    height: .5rem;
    background-color: $danger;
    border-radius: 50%;
  }
}
</style>

