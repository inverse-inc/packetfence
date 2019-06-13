<template>
  <b-row class="pf-documentation overflow-hidden">
    <b-col md="3" xl="2" class="pf-sidebar border-bottom d-print-none" ref="documentList">
      <div class="pf-sidebar-links mt-3">
        <b-nav class="pf-sidenav" vertical>
          <b-nav-item v-for="document in index" :key="document.name"
            :active="document.text === title"
            :disabled="isLoading"
            exact-active-class="active"
            @click.stop.prevent="loadDocument(document)">
            <div class="pf-sidebar-item">
              {{ document.text }} <icon class="mx-1" name="info-circle" v-show="document.text === title"></icon>
            </div>
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
    <b-col md="9" xl="10" class="border-gray border-bottom py-2">
      <!-- document viewer -->
      <b-card no-body class="pf-documentation-document" :class="{ 'fullscreen': fullscreen }">
        <b-card-header>
          <template v-if="!fullscreen">
            <b-button-close @click="closeViewer" v-b-tooltip.hover.left.d300 :title="$t('Close')" class="ml-3"><icon name="times"></icon></b-button-close>
            <b-button-close @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="$t('Show Fullscreen')" class="ml-3"><icon name="expand"></icon></b-button-close>
          </template>
          <b-button-close v-else @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="$t('Exit Fullscreen')" class="ml-3"><icon name="compress"></icon></b-button-close>
          <h4 class="d-inline mb-0 mr-3">{{ title }}</h4>
        </b-card-header>

        <!-- HTML document -->
        <iframe v-show="!isLoading" v-if="path" ref="document" name="documentFrame" frameborder="0" class="pf-documentation-frame"
          :src="`/static/doc/${path}`"
          @load="initDocument()"
        ></iframe>
        <b-container class="pf-documentation-frame my-5" v-if="isLoading">
          <b-row class="justify-content-md-center text-secondary h-100">
            <b-col cols="12" md="auto" class="align-self-center">
              <b-media>
                <icon name="circle-notch" scale="2" slot="aside" spin></icon>
                <h4>{{ $t('Loading Documentation') }}</h4>
                <p class="font-weight-light">{{ title }}</p>
              </b-media>
            </b-col>
          </b-row>
        </b-container>

        <!-- IMG viewer -->
        <b-modal v-model="showImageModal" size="xl" centered id="imageModal" scrollable hide-footer>
          <template slot="modal-title">{{ image.alt }}</template>
          <div class="p-3 text-center">
            <img :src="image.src" :alt="image.alt" style="width: 100%; height: auto;" />
          </div>
        </b-modal>
      </b-card>
    </b-col>
  </b-row>
</template>

<script>
import VueScrollTo from 'vue-scrollto'
import TextHighlight from 'vue-text-highlight'

export default {
  name: 'pfDocumentation',
  components: {
    TextHighlight
  },
  data () {
    return {
      showImageModal: false,
      image: false,
      isLoading: false
    }
  },
  computed: {
    index () {
      return this.$store.getters['documentation/index'] || []
    },
    showViewer () {
      return this.$store.getters['documentation/showViewer']
    },
    fullscreen () {
      return this.$store.getters['documentation/fullscreen']
    },
    path () {
      return this.$store.getters['documentation/path']
    },
    hash () {
      return this.$store.getters['documentation/hash']
    },
    title () {
      return this.$store.getters['documentation/title']
    },
    hasDefaultSlot () {
      return 'default' in this.$slots
    }
  },
  methods: {
    loadDocument (document) {
      this.$store.dispatch('documentation/setPath', document.name)
    },
    initDocument () {
      const here = new URL(window.location.href)
      const documentFrame = window.frames['documentFrame'].document.body
      documentFrame.addEventListener('click', (event) => { // iframe clicks blur the parent window
        window.focus() // regain focus
      })
      // inject css
      const styles = `
        /*
         * default styles
        */
        body {
          font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
          font-style: normal;
          font-variant: normal;
          font-size: .9rem;
        }
        h1, h2, h3, h4, h5, h6,
        #toctitle, .sidebarblock > .content > .title {
          font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica Neue,Arial,"Noto Sans",sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji";
          font-weight: 300;
          font-style: normal;
          color: #495057 !important;
          margin-top: 1em !important;
          margin-bottom: .5em !important;
          line-height: 1.0125em;
        }
        code,
        .content > pre {
          color: #ba3925;
        }
        .caution > table tr td.icon > .title,
        .note > table tr td.icon > .title,
        .warning > table tr td.icon > .title {
          font-family: "Droid Sans Mono","DejaVu Sans Mono",monospace;
          font-weight: 400;
          min-width: 100px;
          text-align: center;
        }
        .caution {
          color: #721c24;
          background-color: #f8d7da;
          border-color: #f5c6cb;
          padding: .75rem .25rem;
          margin-bottom: 1.25em;
        }
        .caution > table,
        .caution > table tr th,
        .caution > table tr td {
          color: #721c24 !important;
          margin-bottom: 0;
        }
        .caution > table tr td.content {
          border-left: 1px dotted #721c24;
        }
        .note {
          background-color: #fff3cd;
          border-color: #ffeeba;
          padding: .75rem .25rem;
          margin-bottom: 1.25em;
        }
        .note > table,
        .note > table tr th,
        .note > table tr td {
          color: #856404 !important;
          margin-bottom: 0;
        }
        .note > table tr td.content {
          border-left: 1px dotted #856404;
        }
        .warning {
          color: #721c24;
          background-color: #f8d7da;
          border-color: #f5c6cb;
          padding: .75rem .25rem;
          margin-bottom: 1.25em;
        }
        .warning > table,
        .warning > table tr th,
        .warning > table tr td {
          color: #721c24 !important;
          margin-bottom: 0;
        }
        .warning > table tr td.content {
          border-left: 1px dotted #721c24;
        }
        .imageblock > .content {
          text-align: center;
        }
        .imageblock > .content > img {
          margin: 1.25em 0;
        }

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
      const links = [...documentFrame.getElementsByTagName('a')]
      links.forEach((link, index) => {
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
            const re = new RegExp('^/static/doc/')
            if (re.test(url.pathname)) { // link to other local document
              link.classList.add('internal-link') // add class to style document links
              link.target = '_self'
              link.href = 'javascript:void(0);' // disable default link
              const path = url.pathname.replace('/static/doc/', '')
              if (path !== this.path) {
                link.addEventListener('click', (event) => {
                  event.preventDefault()
                  this.$store.dispatch('documentation/setPath', path)
                })
              } else if (url.hash.charAt(0) === '#') {
                link.addEventListener('click', (event) => {
                  event.preventDefault()
                  this.$store.dispatch('documentation/setHash', url.hash.substr(1))
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
      images.forEach((image, index) => {
        const width = image.naturalWidth
        const height = image.naturalHeight
        if (width >= 100 || height >= 100) { // ignore thumbnails
          image.setAttribute('style', 'cursor: pointer')
          image.setAttribute('title', this.$i18n.t('Click to expand'))
          image.addEventListener('click', (event) => {
            this.image = { src: image.src, alt: image.alt || image.src, width, height }
            this.showImageModal = true
          })
        }
      })
      if (this.isLoadingTimeout) {
        clearTimeout(this.isLoadingTimeout)
      }
      this.isLoading = false
      if (this.hash) {
        this.$nextTick(() => {
          this.scrollToSection(this.hash)
        })
      }
    },
    openViewer () {
      this.$store.dispatch('documentation/openViewer')
    },
    closeViewer () {
      this.$store.dispatch('documentation/closeViewer')
    },
    toggleFullscreen () {
      this.$store.dispatch('documentation/toggleFullscreen')
    },
    scrollToSection (section) {
      const { $refs: { document: { contentWindow: { document: iframeDocument } = {} } = {} } = {} } = this
      if (iframeDocument) {
        const iframeHtml = iframeDocument.getElementsByTagName('html')[0]
        if (iframeHtml) {
          VueScrollTo.scrollTo(iframeDocument.getElementById(section), 300, { // animated scroll to hash in iframe
            container: iframeHtml,
            cancelable: false
          })
        }
      }
      return false
    },
    scrollToTop () {
      VueScrollTo.scrollTo('.navbar', 300, { // animated scroll to top of page
        cancelable: false
      })
    }
  },
  watch: {
    showViewer: function (a, b) {
      if (a) { // shown
        if (!this.path) { // initial title/path
          this.$store.dispatch('documentation/setPath', 'PacketFence_Installation_Guide.html')
          this.isLoading = true
        }
        this.$nextTick(() => {
          this.scrollToTop()
        })
        this.$refs.documentList.scrollTop = 0
        if (this.hash) {
          this.$nextTick(() => {
            this.scrollToSection(this.hash)
          })
        }
      }
    },
    fullscreen: {
      handler: function (a, b) {
        if (a) { // fullscreen
          if (!document.body.classList.contains('modal-open')) { // hide body scrollbar
            document.body.classList.add('modal-open')
            document.body.classList.add('pf-documentation-fullscreen')
          }
          this.$store.dispatch('events/unbind')
        } else { // not fullscreen
          if (document.body.classList.contains('modal-open')) { // show body scrollbar
            document.body.classList.remove('modal-open')
            document.body.classList.remove('pf-documentation-fullscreen')
          }
          this.$store.dispatch('events/bind')
        }
      }
    },
    path: {
      handler: function (a, b) {
        if (a) {
          this.isLoading = true
          this.isLoadingTimeout = setTimeout(() => {
            this.isLoading = false // in case of error
          }, 3000)
          this.$nextTick(() => {
            this.scrollToTop()
          })
        }
      }
    },
    hash: {
      handler: function (a, b) {
        if (a) {
          this.scrollToSection(a)
        }
      }
    },
    '$route' (to, from) {
      if (from.path.split('/')[1] !== to.path.split('/')[1]) {
        this.$store.dispatch('documentation/closeViewer')
      }
    }
  },
  mounted () {
    this.$store.dispatch('documentation/getIndex')
  }
}
</script>

<style lang="scss">
  @import "../../node_modules/bootstrap/scss/functions";
  @import "../../node_modules/bootstrap/scss/mixins/breakpoints";
  @import "../styles/variables";

  $pf-documentation-height: 50vh;

  .pf-documentation {
    height: $pf-documentation-height;
    .pf-sidebar {
      overflow-y: auto;
      @include media-breakpoint-up(md) {
        @supports (position: sticky) {
          top: 0;
          max-height: calc(#{$pf-documentation-height});
        }
      }
    }
    .pf-documentation-frame {
      height: calc(#{$pf-documentation-height} - #{map-get($spacers, 6)} - 2 * #{map-get($spacers, 2)});
    }
  }
  .pf-documentation-document {
    &.fullscreen {
      position: fixed !important;
      z-index: $zindex-modal-backdrop;
      top: 0 !important;
      right: 0 !important;
      bottom: 0 !important;
      left: 0 !important;
      overflow-x: hidden;
      overflow-y: auto;
      width: 100% !important;
      border: none !important;
    }
  }
  .pf-documentation-container > .row {
    transition: all 300ms ease;
  }
  .pf-documentation-active > .row {
    transform: translateY(0);
  }
  .pf-documentation-container:not(.pf-documentation-active) > .row {
    transform: translateY(-#{$pf-documentation-height});
  }
  .pf-documentation-fullscreen {
    .pf-documentation,
    .pf-documentation .pf-documentation-frame {
      height: calc(100vh - #{map-get($spacers, 6)});
    }
  }
</style>
