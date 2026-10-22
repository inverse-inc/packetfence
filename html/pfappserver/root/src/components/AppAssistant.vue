<template>
  <div class="assistant overflow-hidden py-2 border-bottom border-gray" :class="{ 'fullscreen': fullscreen }">
    <the-view>
      <template #header-actions>
        <b-button-close @click="$emit('close')" v-b-tooltip.hover.left.d300 :title="$t('Close')" class="ml-3"><icon name="times" /></b-button-close>
        <b-button-close @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="fullscreen ? $t('Exit Fullscreen') : $t('Show Fullscreen')" class="ml-3">
          <icon :name="fullscreen ? 'compress' : 'expand'" />
        </b-button-close>
        <b-button-close @click="openPage" v-b-tooltip.hover.left.d300 :title="$t('Open as a page')" class="ml-3"><icon name="external-link-alt" /></b-button-close>
      </template>
    </the-view>
  </div>
</template>

<script>
import { onBeforeUnmount, ref, watch } from '@vue/composition-api'
import { beforeEnter } from '@/views/Assistant/_router'

const TheView = () => import(/* webpackChunkName: "Assistant" */ '@/views/Assistant/_components/TheView')

const components = {
  TheView
}

const props = {
  show: {
    type: Boolean
  }
}

const setup = (props, context) => {
  const { emit, root: { $router } = {} } = context

  beforeEnter() // registers the "$_assistant" store module

  // same body handling as the documentation viewer's fullscreen
  const fullscreen = ref(false)
  const setBodyFullscreen = on => {
    document.body.classList.toggle('modal-open', on)
    document.body.classList.toggle('assistant-fullscreen', on)
  }
  watch(fullscreen, setBodyFullscreen)
  watch(() => props.show, show => {
    if (!show)
      fullscreen.value = false
  })
  onBeforeUnmount(() => setBodyFullscreen(false))

  const toggleFullscreen = () => { fullscreen.value = !fullscreen.value }
  const openPage = () => {
    emit('close')
    $router.push('/assistant').catch(e => { if (e.name !== 'NavigationDuplicated') throw e })
  }

  return { fullscreen, toggleFullscreen, openPage }
}

// @vue/component
export default {
  name: 'app-assistant',
  components,
  props,
  setup
}
</script>

<style lang="scss">
  // slides like the documentation viewer, and reuses its slide-in-top /
  // slide-out-top keyframes (AppDocumentation.vue), which share this height
  $assistant-height: 50vh;
  $slide-in-duration: 0.3s;
  $slide-out-duration: 0.15s;

  .assistant {
    display: none; // hidden by default
    height: $assistant-height;
    // nested under .the-assistant to out-specify TheView's page-height rules
    .the-assistant .the-assistant-card {
      height: calc(#{$assistant-height} - 2 * #{map-get($spacers, 2)});
    }
    .the-assistant .the-threads {
      max-height: calc(#{$assistant-height} - 11rem);
    }
    &.fullscreen {
      position: fixed !important;
      z-index: $zindex-modal-backdrop;
      top: #{map-get($spacers, 6)} !important; // navbar height
      right: 0 !important;
      bottom: 0 !important;
      left: 0 !important;
      height: auto;
      padding: 0 #{map-get($spacers, 3)};
      background-color: $body-bg;
      .the-assistant .the-assistant-card {
        height: calc(100vh - #{map-get($spacers, 6)} - 2 * #{map-get($spacers, 2)});
      }
      .the-assistant .the-threads {
        max-height: calc(100vh - #{map-get($spacers, 6)} - 11rem);
      }
    }
  }

  .assistant-enter {
    animation: slide-in-top $slide-in-duration cubic-bezier(0.250, 0.460, 0.450, 0.940) both;
    .assistant {
      display: block;
    }
  }

  .assistant-open {
    .assistant {
      display: block;
    }
  }

  .assistant-leave {
    animation: slide-out-top $slide-out-duration cubic-bezier(0.250, 0.460, 0.450, 0.940) both;
    .assistant {
      display: block;
    }
  }
</style>
