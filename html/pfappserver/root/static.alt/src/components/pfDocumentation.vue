<template>
  <b-row>
    <b-col cols="12" md="3" xl="2" class="pf-sidebar d-print-none">
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
        <b-nav-item v-for="document in filteredDocuments" :key="document.name"
          :active="document.text === title"
          exact-active-class="active"
          @click.stop.prevent="loadDocument(document)"
        >
          <div class="pf-sidebar-item" :class="{ 'ml-3': indent }">
            <text-highlight :queries="[filter]">{{ document.text }}</text-highlight>
            <icon class="mx-1" name="info-circle"></icon>
          </div>
        </b-nav-item>
      </b-nav>
    </b-col>
    <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
      <b-card no-body class="document" :class="{ 'fullscreen': fullscreen }">
        <b-card-header>
          <template v-if="!fullscreen">
            <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')" class="ml-3"><icon name="times"></icon></b-button-close>
            <b-button-close @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="$t('Show Fullscreen')" class="ml-3"><icon name="expand"></icon></b-button-close>
          </template>
          <b-button-close v-else @click="toggleFullscreen" v-b-tooltip.hover.left.d300 :title="$t('Exit Fullscreen [ESC]')" class="ml-3"><icon name="compress"></icon></b-button-close>
          <h4 class="mb-0" v-t="title"></h4>
        </b-card-header>

        <!-- document viewer -->
        <b-embed ref="document" name="documentFrame" class="h-100" type="iframe" aspect="16by9"
          :src="`/static/doc/${path}${(hash) ? '#' + hash : ''}`"
          @load="initDocument()"
          allowfullscreen
        ></b-embed>

        <!-- image viewer -->
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
import TextHighlight from 'vue-text-highlight'

export default {
  name: 'pfDocumentation',
  components: {
    TextHighlight
  },
  computed: {
    documents () {
      return this.$store.state.documentation.documents
    },
    filteredDocuments () {
      if (!(this.documents && 'length' in this.documents)) {
        return []
      }
      const re = new RegExp(this.filter, 'i')
      return this.documents.map(document => {
        return { ...document, ...{ text: document.name.replace(/\.html/g, '').replace(/_/g, ' ').replace(/^PacketFence /, '') } }
      }).filter(document => {
        return re.test(document.text)
      }).sort((a, b) => {
        return a.text.localeCompare(b.text)
      })
    },
    fullscreen () {
      return this.$store.state.documentation.fullscreen
    }
  },
  methods: {
    loadDocument (document) {
      this.title = document.text
      this.setPath(document.name)
      this.$scrollTo(this.$refs.document)
    },
    initDocument () {
      const documentFrame = window.frames['documentFrame'].document.body
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
            const re = new RegExp('^/static/doc/')
            if (re.test(url.pathname)) { // link to an other document
              link.className += ' document-link' // add class to style document links
              link.target = '_self'
              link.href = 'javascript:void(0);' // disable default link
              link.addEventListener('click', (event) => {
                this.setHash(url.hash)
                const path = url.pathname.replace('/static/doc/', '')
                if (path !== this.path) {
                  this.setPath(path)
                } else {
                  this.$scrollTo(this.$refs.document)
                }
              })
              return
            }
            // replace href with current hostname:port
            const here = new URL(window.location.href)
            url.port = '1443'
            url.hostname = here.hostname
            link.href = url.toString()
            break
        }
        // unhandled URLs
        link.className += ' external-link' // add class to style external links
        link.target = '_blank'  // open in a new tab
      })
      // rewrite images
      const images = [...documentFrame.getElementsByTagName('img')]
      images.forEach((image, index) => {
        const width = image.naturalWidth, height = image.naturalHeight
        if (width >= 100 || height >= 100) { // ignore thumbnails
          image.setAttribute('style', 'cursor: pointer')
          image.setAttribute('title', this.$i18n.t('Click to expand'))
          image.addEventListener('click', (event) => {
            this.image = { src: image.src, alt: image.alt || image.src, width, height }
            this.showImageModal = true
          })
        }
      })
      this.$nextTick(() => {
        this.$scrollTo(this.$refs.document)
      })
    },
    focusFilter () {
      this.$refs.filter.$el.focus()
      this.$nextTick(() => {
        this.$refs.filter.$el.select()
      })
    },
    setPath (path) {
      console.log('setPath', path)
      this.$set(this, 'path', path)
    },
    setHash (hash) {
      while (hash.charAt(0) === '#') { // remove leading '#'
        hash = hash.substr(1)
      }
      console.log('setHash', hash)
      this.$set(this, 'hash', hash)
    },
    toggleFullscreen () {
      this.$store.dispatch('documentation/toggleFullscreen')
    }
  },
  data () {
    return {
      title: 'Administration Guide',
      path: 'PacketFence_Administration_Guide.html',
      hash: null,
      filter: '',
      showImageModal: false,
      image: false
    }
  },
  mounted () {
    this.$store.dispatch('documentation/getDocuments')
  },
  watch: {
    fullscreen: {
      handler: function (a, b) {
        if (a) {
          if (!document.body.classList.contains('no-scroll')) document.body.classList.add('no-scroll')
        } else {
          if (document.body.classList.contains('no-scroll')) document.body.classList.remove('no-scroll')
        }
      }
    }
  }
}
</script>

<style lang="scss">
  body.no-scroll {
    overflow-x: hidden;
    overflow-y: hidden;
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
      z-index: 1036;
    }
  }
</style>
