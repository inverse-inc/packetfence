<template>
  <b-link class="text-nowrap" @click="onClick">{{ text || $i18n.t('Learn more') }}</b-link>
</template>
<script>
// opens the documentation viewer at a section of the PacketFence Connector
// chapter (docs/installation/pfconnector.asciidoc)
export const props = {
  anchor: {
    type: String,
    default: 'pfconnector'
  },
  text: {
    type: String
  }
}

export const setup = (props, context) => {
  const { root: { $store } = {} } = context
  const onClick = () => {
    $store.dispatch('documentation/openViewer')
    $store.dispatch('documentation/setPath', 'PacketFence_Installation_Guide.html')
    $store.dispatch('documentation/setHash', `#${props.anchor}`)
  }
  return {
    onClick
  }
}

// @vue/component
export default {
  name: 'base-doc-link',
  inheritAttrs: false,
  props,
  setup
}
</script>
