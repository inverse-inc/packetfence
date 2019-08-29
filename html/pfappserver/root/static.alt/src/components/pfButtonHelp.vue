<template>
  <span @click="loadHelp()">
    <icon class="pf-button-help text-secondary" name="regular/question-circle"
      :title="$t('Click to view {documentName}', { documentName })" v-b-tooltip.hover.top.d300
      v-bind="$attrs"
    ></icon>
  </span>
</template>

<script>
export default {
  name: 'pfButtonHelp',
  props: {
    url: {
      type: String,
      default: 'PacketFence_Administration_Guide.html#_about_this_guide'
    }
  },
  computed: {
    index () {
      return this.$store.state.documentation.index
    },
    urlByParts () {
      const [ path, hash ] = this.url.split('#')
      return { path, hash: `#${hash}` }
    },
    documentName () {
      const { path } = this.urlByParts
      let document = this.index.find(d => d.name === path)
      if (Object.keys(document).length > 0) {
        return document.name.replace(/\.html/g, '').replace(/_/g, ' ').replace(/^PacketFence /, '')
      }
      return path
    }
  },
  methods: {
    loadHelp () {
      const { path, hash } = this.urlByParts
      this.$store.dispatch('documentation/openViewer')
      this.$store.dispatch('documentation/setPath', path)
      this.$store.dispatch('documentation/setHash', hash)
    }
  }
}
</script>

<style>
  .pf-button-help {
    cursor: pointer;
  }
  .pf-button-help:hover {
    fill: var(--primary);
  }
</style>
