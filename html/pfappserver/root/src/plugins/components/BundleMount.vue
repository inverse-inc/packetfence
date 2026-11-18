<template>
  <div class="plugin-bundle">
    <div v-if="error" class="p-3 text-danger">
      <icon name="exclamation-triangle" class="mr-1" /> {{ $t('The plugin is unavailable.') }}
    </div>
    <div v-else-if="loading" class="p-3 text-secondary">
      <icon name="circle-notch" spin class="mr-1" /> {{ $t('Loading...') }}
    </div>
    <div ref="el" :key="pluginId" />
  </div>
</template>
<script>
/**
 * Mounts the code of a bundle plugin (src/plugins/bundle.js) at a mount of
 * core: "page" (the route of the plugin) or "navbar-panel" (the navbar panel).
 */
import { loadBundle, hostApi } from '../bundle'

export default {
  name: 'plugin-bundle-mount',
  props: {
    pluginId: { type: String, required: true },
    kind: { type: String, default: 'page' }
  },
  data: () => ({ loading: true, error: false }),
  watch: {
    pluginId () {
      this.unmount()
      this.mount()
    }
  },
  mounted () {
    this.mount()
  },
  beforeDestroy () {
    this.unmount()
  },
  methods: {
    mount () {
      const id = this.pluginId
      this.loading = true
      this.error = false
      loadBundle(id, this.$store.state.session.token)
        .then(bundle => {
          if (this._isDestroyed || id !== this.pluginId)
            return
          const unmount = bundle.mount(this.$refs.el, hostApi(id, { router: this.$router, store: this.$store }), { kind: this.kind })
          this.unmountBundle = (typeof unmount === 'function') ? unmount : null
          this.loading = false
        })
        .catch(() => {
          this.loading = false
          this.error = true
        })
    },
    unmount () {
      if (this.unmountBundle) {
        try {
          this.unmountBundle()
        } catch (err) {
          // eslint-disable-next-line no-console
          console.error('[pf-ui-plugins]', `${this.pluginId}: unmount failed`, err)
        }
        this.unmountBundle = null
      }
    }
  }
}
</script>
