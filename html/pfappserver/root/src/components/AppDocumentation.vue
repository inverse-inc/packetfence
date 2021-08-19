<template>
  <div class="documentation overflow-hidden py-2 border-bottom border-gray">
    <!-- document viewer -->
    <b-card no-body class="documentation-document" :class="{ 'fullscreen': fullscreen }">
      <b-card-header>
        <template v-if="!fullscreen">
          <b-button-close @click="closeViewer" v-b-tooltip.hover.left.d300 :title="$t('Close')" class="ml-3"><icon name="times"></icon></b-button-close>
          <b-button-close @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="$t('Show Fullscreen')" class="ml-3"><icon name="expand"></icon></b-button-close>
        </template>
        <b-button-close v-else @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="$t('Exit Fullscreen')" class="ml-3"><icon name="compress"></icon></b-button-close>
        <h4 class="d-inline mb-0 mr-3"><icon class="mr-2" name="book"></icon>{{ title }}</h4>
      </b-card-header>
      <b-row no-gutters>
        <b-col md="3" xl="2" class="section-sidebar d-print-none" ref="refDocumentList">
          <div class="section-sidebar-links mt-3">
            <b-nav class="section-sidenav" vertical>
              <b-nav-item v-for="document in index" :key="document.name"
                :active="document.text === title"
                :disabled="isLoading"
                exact-active-class="active"
                @click.stop.prevent="loadDocument(document)">
                <div class="section-sidebar-item">{{ document.text }}</div>
              </b-nav-item>
            </b-nav>
            <!-- info + support link -->
            <hr />
            <slot />
            <div class="m-3">
              <b-button href="https://packetfence.org/support.html#/commercial" target="_blank" size="sm" block>
                {{ $t('Support Inquiry') }}<icon class="ml-1" name="external-link-alt"> </icon>
              </b-button>
            </div>
          </div>
        </b-col>
        <b-col md="9" xl="10">
          <!-- HTML document -->
          <iframe v-show="!isLoading" v-if="path" ref="refDocument" name="documentFrame" frameborder="0" class="documentation-frame"
            :src="`/static/doc/${path}`"
            @load="initDocument()"
          ></iframe>
          <b-container class="documentation-frame my-5" v-if="isLoading">
            <b-row class="justify-content-md-center text-secondary h-100">
              <b-col cols="12" md="auto" class="align-self-center">
                <b-media>
                  <template v-slot:aside><icon name="circle-notch" scale="2" spin></icon></template>
                  <h4>{{ $t('Loading Documentation') }}</h4>
                  <p class="font-weight-light">{{ title }}</p>
                </b-media>
              </b-col>
            </b-row>
          </b-container>
          <!-- IMG viewer -->
          <b-modal v-model="showImageModal" size="xl" centered id="imageModal" scrollable hide-footer>
            <template v-slot:modal-title>{{ image.alt }}</template>
            <div class="p-3 text-center">
              <img :src="image.src" :alt="image.alt" style="width: 100%; height: auto;" />
            </div>
          </b-modal>
        </b-col>
      </b-row>
    </b-card>
  </div>
</template>

<script>
import Vue from 'vue'
import store from '@/store'

Vue.mixin({
  beforeRouteLeave(to, from, next) {
    store.dispatch('documentation/closeViewer')
      .finally(() => next())
  }
})

import { computed, onMounted, nextTick, ref, watch } from '@vue/composition-api'
import VueScrollTo from 'vue-scrollto'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { refs, root: { $store } = {} } = context

  // template refs
  const refDocument = ref(null)
  const refDocumentList = ref(null)

  const index = computed(() => $store.getters['documentation/index'] || [])
  const _showViewer = computed(() => $store.getters['documentation/showViewer'])
  watch(_showViewer, a => {
    if (a) { // shown
      if (!path.value) { // initial title/path
        $store.dispatch('documentation/setPath', 'PacketFence_Installation_Guide.html')
        isLoading.value = true
      }
      nextTick(() => _scrollToTop())
      refs.refDocumentList.scrollTop = 0
      if (_hash.value)
        nextTick(() => _scrollToSection(_hash.value))
    }
  })
  const fullscreen = computed(() => $store.getters['documentation/fullscreen'])
  watch(fullscreen, a => {
    if (a) { // fullscreen
      if (!document.body.classList.contains('modal-open')) { // hide body scrollbar
        document.body.classList.add('modal-open')
        document.body.classList.add('documentation-fullscreen')
      }
      $store.dispatch('events/unbind')
    } else { // not fullscreen
      if (document.body.classList.contains('modal-open')) { // show body scrollbar
        document.body.classList.remove('modal-open')
        document.body.classList.remove('documentation-fullscreen')
      }
      $store.dispatch('events/bind')
    }
  })
  const path = computed(() => $store.getters['documentation/path'])
  watch(path, a => {
    if (a) {
      isLoading.value = true
      isLoadingTimeout = setTimeout(() => {
        isLoading.value = false // in case of error
      }, 3000)
      nextTick(() => _scrollToTop())
    }
  })
  const _hash = computed(() => $store.getters['documentation/hash'])
  watch(_hash, a => {
    if (a)
      _scrollToSection(a)
  })
  const title = computed(() => $store.getters['documentation/title'])

  const showImageModal = ref(false)
  const image = ref(false)
  const isLoading = ref(false)
  let isLoadingTimeout

  const loadDocument = document => $store.dispatch('documentation/setPath', document.name)
  const initDocument = () => {
    const here = new URL(window.location.href)
    const documentFrame = window.frames['documentFrame'].document.body
    documentFrame.addEventListener('click', () => { // iframe clicks blur the parent window
      window.focus() // regain focus
    })

    // inject css
    const styles = `
      /*
        * custom styles
      */
      .external-link {
        background: transparent url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 576 512" xml:space="preserve" width="1em" height="1em"><path d="M576 24v127.984c0 21.461-25.96 31.98-40.971 16.971l-35.707-35.709-243.523 243.523c-9.373 9.373-24.568 9.373-33.941 0l-22.627-22.627c-9.373-9.373-9.373-24.569 0-33.941L442.756 76.676l-35.703-35.705C391.982 25.9 402.656 0 424.024 0H552c13.255 0 24 10.745 24 24zM407.029 270.794l-16 16A23.999 23.999 0 0 0 384 303.765V448H64V128h264a24.003 24.003 0 0 0 16.97-7.029l16-16C376.089 89.851 365.381 64 344 64H48C21.49 64 0 85.49 0 112v352c0 26.51 21.49 48 48 48h352c26.51 0 48-21.49 48-48V287.764c0-21.382-25.852-32.09-40.971-16.97z" fill="%232156a5"></path></svg>') right top no-repeat !important;
        background-size: 1em;
        padding-right: 1.25em;
      }
    `
    const head = window.frames['documentFrame'].document.getElementsByTagName('head')[0]
    let css = document.createElement('style')
    css.type = 'text/css'
    css.appendChild(document.createTextNode(styles))
    head.appendChild(css)

    // rewrite links
    const re = new RegExp('^/static/doc/')
    const links = [...documentFrame.getElementsByTagName('a')]
    links.forEach((link) => {
      let url = new URL(link.href)
      switch (true) {
        case url.port === '1443': // local link
        case url.hostname === '%3Chostname%3E':
        case url.hostname === 'your_portal_hostname':
        case url.hostname === 'your_portal_ip':
        case url.hostname === 'pf_management_ip':
        case url.hostname === '%3Cyour_captive_portal_ip%3E':
        case url.hostname === '_ip_address_of_packetfence':
        case url.hostname === here.hostname:
          if (re.test(url.pathname)) { // link to other local document
            link.classList.add('internal-link') // add class to style document links
            link.target = '_self'
            link.href = 'javascript:void(0);' // disable default link
            const _path = url.pathname.replace('/static/doc/', '')
            if (_path !== path.value) {
              link.addEventListener('click', (event) => {
                event.preventDefault()
                $store.dispatch('documentation/setPath', _path)
              })
            } else if (url.hash.charAt(0) === '#') {
              link.addEventListener('click', (event) => {
                event.preventDefault()
                $store.dispatch('documentation/setHash', url.hash.substr(1))
              })
            }
            return
          }
          // replace href with current hostname:port
          url.port = '1443'
          url.hostname = here.hostname
          link.href = url.toString()
          break
      }
      // unhandled URLs
      link.classList.add('external-link') // add class to style external links
      link.target = '_blank' // open in a new tab
    })

    // rewrite images
    const images = [...documentFrame.getElementsByTagName('img')]
    images.forEach(_image => {
      const width = _image.naturalWidth
      const height = _image.naturalHeight
      if (width >= 100 || height >= 100) { // ignore thumbnails
        _image.setAttribute('style', 'cursor: pointer')
        _image.setAttribute('title', i18n.t('Click to expand'))
        _image.addEventListener('click', () => {
          image.value = { src: _image.src, alt: _image.alt || _image.src, width, height }
          showImageModal.value = true
        })
      }
    })
    if (isLoadingTimeout)
      clearTimeout(isLoadingTimeout)
    isLoading.value = false
    if (_hash.value)
      nextTick(() => _scrollToSection(_hash.value))
  }
  const openViewer = () => $store.dispatch('documentation/openViewer')
  const closeViewer = () => $store.dispatch('documentation/closeViewer')
  const toggleFullscreen = () => $store.dispatch('documentation/toggleFullscreen')
  const _scrollToSection = section => {
    const iframeDocument = refs.refDocument.contentWindow.document
    if (iframeDocument) {
      const iframeHtml = iframeDocument.getElementById('guide')
      if (iframeHtml) {
        VueScrollTo.scrollTo(iframeDocument.getElementById(section), 300, { // animated scroll to hash in iframe
          container: iframeHtml,
          cancelable: false
        })
      }
    }
    return false
  }
  const _scrollToTop = () => {
    VueScrollTo.scrollTo('.navbar', 300, { // animated scroll to top of page
      cancelable: false
    })
  }

  onMounted(() => $store.dispatch('documentation/getIndex'))

  return {
    // template refs
    refDocument,
    refDocumentList,

    index,
    fullscreen,
    path,
    title,
    showImageModal,
    image,
    isLoading,
    loadDocument,
    initDocument,
    openViewer,
    closeViewer,
    toggleFullscreen
  }
}

// @vue/component
export default {
  name: 'app-documentation',
  setup
}
</script>

<style lang="scss">
  $documentation-height: 50vh;
  $slide-in-duration: 0.3s;
  $slide-out-duration: 0.15s;

  .documentation {
    display: none; // hidden by default
    height: $documentation-height;
    .section-sidebar {
      overflow-y: auto;
      @include media-breakpoint-up(md) {
        @supports (position: sticky) {
          top: 0;
          max-height: calc(#{$documentation-height} - #{map-get($spacers, 6)} - 2 * #{map-get($spacers, 2)});
        }
      }
    }
    .documentation-frame {
      width: 100%;
      height: calc(#{$documentation-height} - #{map-get($spacers, 6)} - 2 * #{map-get($spacers, 2)});
    }
  }
  .documentation-document {
    &.fullscreen {
      position: fixed !important;
      z-index: $zindex-modal-backdrop;
      top: #{map-get($spacers, 6)} !important; // navbar height
      right: 0 !important;
      bottom: 0 !important;
      left: 0 !important;
      overflow-x: hidden;
      overflow-y: auto;
      width: 100% !important;
      border: none !important;
    }
  }
  .documentation-fullscreen {
    .documentation,
    .documentation .documentation-frame {
      height: calc(100vh - #{map-get($spacers, 6)} - #{map-get($spacers, 5)}); // 100% view height - navbar height - card header height
    }
  }

.documentation-enter {
  animation: slide-in-top $slide-in-duration cubic-bezier(0.250, 0.460, 0.450, 0.940) both;
  .documentation {
    display: block;
  }
}

.documentation-leave {
  animation: slide-out-top $slide-out-duration cubic-bezier(0.250, 0.460, 0.450, 0.940) both;
  .documentation {
    display: block;
  }
}

@keyframes slide-in-top {
  0% {
    transform: translateY(-#{$documentation-height});
  }
  100% {
    transform: translateY(0);
  }
}

@keyframes slide-out-top {
  0% {
    transform: translateY(0);
  }
  100% {
    transform: translateY(-#{$documentation-height});
  }
}
</style>
