<template>
  <span @click="onClick" class="align-items-center">
    <icon name="regular/question-circle" scale="1.25"
      class="base-button-help text-secondary"
      :title="$i18n.t('Click to view {documentName}', { documentName })" v-b-tooltip.hover.top.d300
    ></icon>
  </span>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'

const props = {
  url: {
    type: String,
    default: 'PacketFence_Administration_Guide.html#_about_this_guide'
  }
}

const setup = (props, context) => {

  const {
    url
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const parsedUrl = computed(() => {
    const [ path, hash ] = (url.value || '').split('#')
    return { path, hash: `#${hash}` }
  })

  const documentName = computed(() => {
    const { path } = parsedUrl.value
    let document = $store.getters['documentation/index'].find(d => d.name === path)
    if (document && Object.keys(document).length > 0) {
      return document.name.replace(/\.html/g, '').replace(/_/g, ' ').replace(/^PacketFence /, '')
    }
    return path
  })

  const onClick = () => {
    const { path, hash } = parsedUrl.value
    $store.dispatch('documentation/openViewer')
    $store.dispatch('documentation/setPath', path)
    $store.dispatch('documentation/setHash', hash)
  }

  return {
    documentName,
    onClick
  }
}

// @vue/component
export default {
  name: 'base-button-help',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.base-button-help {
  &:hover {
    fill: var(--primary);
  }
  cursor: pointer;
}
</style>
