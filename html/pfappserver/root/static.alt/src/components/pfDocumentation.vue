<template>
  <b-row class="documentViewer" ref="documentViewer" :class="{ 'hidden': !showViewer }">
    <b-col cols="12" md="3" xl="2" class="pf-sidebar d-print-none h-100 border-gray border-bottom" ref="documentList">
      <!-- filter -->
      <div class="pf-sidebar-filter d-flex align-items-center">
        <b-input-group>
          <b-input-group-prepend>
            <icon class="h-auto" name="search" scale=".75"></icon>
          </b-input-group-prepend>
          <b-form-input ref="filter" v-model="filter" type="text" :placeholder="$t('Filter')"></b-form-input>
          <b-input-group-append v-if="filter">
            <b-btn @click="filter = ''"><icon name="times-circle"></icon></b-btn>
          </b-input-group-append>
        </b-input-group>
        <b-btn class="pf-sidebar-filter-toggle d-md-none p-0 ml-3" variant="link" v-b-toggle.pf-sidebar-links>
          <icon name="bars"></icon>
        </b-btn>
      </div>
      <b-nav class="pf-sidenav" vertical>
        <b-nav-item v-for="document in filteredIndex" :key="document.name"
          :active="document.text === title"
          exact-active-class="active"
          @click.stop.prevent="loadDocument(document)"
        >
          <div class="pf-sidebar-item">
            <text-highlight :queries="[filter]">{{ document.text }}</text-highlight>
            <icon class="mx-1" name="info-circle"></icon>
          </div>
        </b-nav-item>
      </b-nav>
    </b-col>
    <b-col cols="12" md="9" xl="10" class="mt-3 border-gray border-bottom pb-3">
      <!-- slot -->
      <b-card v-if="hasDefaultSlot" no-body class="mb-3">
        <slot/>
      </b-card>

      <!-- document viewer -->
      <b-card no-body class="document h-100" :class="{ 'fullscreen': fullscreen }">
        <b-card-header>
          <template v-if="!fullscreen">
            <b-button-close @click="closeViewer" v-b-tooltip.hover.left.d300 :title="$t('Close')" class="ml-3"><icon name="times"></icon></b-button-close>
            <b-button-close @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="$t('Show Fullscreen')" class="ml-3"><icon name="expand"></icon></b-button-close>
          </template>
          <b-button-close v-else @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="$t('Exit Fullscreen')" class="ml-3"><icon name="compress"></icon></b-button-close>
          <h4 class="mb-0" v-t="title"></h4>
        </b-card-header>

        <!-- HTML document -->
        <iframe ref="document" name="documentFrame" class="h-100" frameborder="0"
          :src="`/static/doc/${path}`"
          @load="initDocument()"
        ></iframe>

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
  computed: {
    index () {
      return this.$store.state.documentation.index
    },
    filteredIndex () {
      if (!(this.index && 'length' in this.index)) {
        return []
      }
      const re = new RegExp(this.filter, 'i')
      return this.index.map(document => {
        return { ...document, ...{ text: document.name.replace(/\.html/g, '').replace(/_/g, ' ').replace(/^PacketFence /, '') } }
      }).filter(document => {
        return re.test(document.text)
      }).sort((a, b) => {
        return a.text.localeCompare(b.text)
      })
    },
    showViewer () {
      return this.$store.state.documentation.showViewer
    },
    fullscreen () {
      return this.$store.state.documentation.fullscreen
    },
    hasDefaultSlot () {
      return 'default' in this.$slots
    }
  },
  methods: {
    loadDocument (document) {
      this.$set(this, 'title', document.text)
      this.$set(this, 'path', document.name)
      this.$nextTick(() => {
        this.scrollToTop()
      })
    },
    initDocument () {
      const here = new URL(window.location.href)
      const documentFrame = window.frames['documentFrame'].document.body
      documentFrame.addEventListener('click', (event) => { // iframe clicks blur the parent window
        window.focus() // regain focus
      })
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
            if (re.test(url.pathname)) { // link to an other document
              link.classList.add('internal-link') // add class to style document links
              link.target = '_self'
              link.href = 'javascript:void(0);' // disable default link
              link.addEventListener('click', (event) => {
                event.preventDefault()
                const path = url.pathname.replace('/static/doc/', '')
                if (path !== this.path) {
                  this.$set(this, 'path', path)
                } else if (url.hash.charAt(0) === '#') {
                  const { $refs: { document: { contentWindow: { document: iframeDocument } = {} } = {} } = {} } = this
                  if (iframeDocument) {
                    const iframeHtml = iframeDocument.getElementsByTagName('html')[0]
                    if (iframeHtml) {
                      const section = iframeDocument.getElementById(url.hash.substr(1))
                      if (section) {
                        VueScrollTo.scrollTo(section, 300, { // animated scroll to hash in iframe
                          container: iframeHtml,
                          cancelable: false
                        })
                        return false
                      }
                    }
                  }
                }
              })
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
    },
    focusFilter () {
      this.$refs.filter.$el.focus()
      this.$nextTick(() => {
        this.$refs.filter.$el.select()
      })
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
    scrollToTop () {
      VueScrollTo.scrollTo('.navbar', 300, { // animated scroll to top of page
        cancelable: false
      })
    }
  },
  data () {
    return {
      filter: '',
      title: 'Administration Guide',
      path: 'PacketFence_Administration_Guide.html',
      showImageModal: false,
      image: false
    }
  },
  mounted () {
    this.$store.dispatch('documentation/getIndex')
  },
  watch: {
    showViewer: function (a, b) {
      if (a) { // shown
        this.$nextTick(() => {
          this.scrollToTop()
        })
        this.$refs.documentList.scrollTop = 0
        this.focusFilter()
      }
    },
    fullscreen: {
      handler: function (a, b) {
        if (a) { // fullscreen
          if (!document.body.classList.contains('modal-open')) { // hide body scrollbar
            document.body.classList.add('modal-open')
            document.body.setAttribute('style', 'padding-right: 14px;')
          }
          this.$store.dispatch('events/unbind')
        } else { // not fullscreen
          if (document.body.classList.contains('modal-open')) { // show body scrollbar
            document.body.classList.remove('modal-open')
            document.body.setAttribute('style', '')
          }
          this.$store.dispatch('events/bind')
        }
      }
    }
  }
}
</script>

<style lang="scss">
  .documentViewer {
    transition: all 300ms ease;
    max-height: 100vh;
    &.hidden {
      overflow-x: hidden;
      overflow-y: hidden;
      max-height: 0vh;
    }
    .pf-sidebar {
      overflow-y: auto;
    }
  }
  .document {
    &.fullscreen {
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      width: 100% !important;
      border: none !important;
      overflow-y: auto;
      overflow-x: hidden;
      z-index: 1045;
    }
  }
</style>
