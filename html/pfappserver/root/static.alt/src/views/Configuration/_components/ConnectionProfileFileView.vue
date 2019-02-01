<template>
  <b-form class="h-100" @submit.prevent="save($event)">
    <b-card class="h-100" no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">
          <router-link :to="{ name: 'connectionProfileFiles', id }">{{ $t('Connection Profile {id}', { id: id }) }}</router-link> / <b>{{ path }}</b>
        </h4>
      </b-card-header>
      <div class="card-body d-flex flex-column">
        <b-form-row class="align-items-center">
          <b-col cols="auto" class="mr-auto">
            <b-dropdown size="sm" variant="outline-secondary" :disabled="isLoading">
              <template slot="button-content">
                <icon name="code" :title="$t('Insert variable')"></icon> {{ $t('Insert variable') }}
              </template>
              <b-dropdown-item v-for="variable in variables" :key="variable" @click="insertVariable(variable)">
                {{ variable }}
              </b-dropdown-item>
            </b-dropdown>
          </b-col>
          <b-col cols="auto">
            <pf-form-toggle class="mb-2" v-model="showLines" @change="toggleLineNumbers">{{ $t('Show line numbers') }}</pf-form-toggle>
          </b-col>
        </b-form-row>
          <!-- Loading progress indicator -->
          <b-container class="my-5" v-if="isLoading && !content">
            <b-row class="justify-content-md-center text-secondary">
              <b-col cols="12" md="auto">
                <icon name="circle-notch" scale="1.5" spin></icon>
              </b-col>
            </b-row>
          </b-container>
          <div class="flex-grow-1 overflow-hidden border-top border-right border-bottom border-left" ref="editorContainer" v-else>
            <transition name="fade">
              <ace-editor v-model="content" theme="chrome" lang="html" :height="editorHeight" @init="initEditor"></ace-editor>
            </transition>
          </div>
      </div>
      <b-card-footer>
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ $t('Save') }}</pf-button-save>
        <pf-button-delete v-if="deletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Config?')" @on-delete="remove($event)"/>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import pfFormToggle from '@/components/pfFormToggle'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
const aceEditor = require('vue2-ace-editor')

export default {
  name: 'ConnectionProfileFileView',
  mixins: [
    pfMixinEscapeKey
  ],
  components: {
    pfFormToggle,
    aceEditor,
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: { // from router
      type: String,
      default: null
    },
    filename: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      deletable: true,
      content: '',
      showLines: true,
      editor: null,
      editorHeight: '0px',
      variables: [ 'logo', 'username', 'user_agent', 'device_class', 'last_switch', 'last_port', 'last_vlan', 'last_connection_type', 'last_ssid' ],
      parentNodes: [],
      invalidForm: true
    }
  },
  computed: {
    path () {
      return this.filename.split('/').join(' / ')
    },
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoadingFiles`]
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'connectionProfileFiles', params: { id: this.id } })
    },
    initEditor (instance) {
      // Load ACE editor extensions
      require('brace/ext/language_tools')
      require('brace/mode/html')
      require('brace/theme/chrome')
      this.editor = instance
      this.editor.setAutoScrollEditorIntoView(true)
      this.resizeEditor()
    },
    resizeEditor () {
      this.editorHeight = this.$refs.editorContainer.clientHeight + 'px'
      this.editor.resize()
    },
    toggleLineNumbers (event) {
      this.editor.renderer.setShowGutter(event.value)
    },
    insertVariable (variable) {
      this.editor.insert(`[% ${variable} %]`)
      this.editor.focus()
    },
    save () {
      const ctrlKey = this.ctrlKey
      const data = {
        id: this.id,
        filename: this.filename,
        content: this.content
      }
      this.$store.dispatch(`${this.storeName}/updateFile`, data).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch(`${this.storeName}/deleteFile`, { id: this.id, filename: this.filename }).then(response => {
        this.close()
      })
    }
  },
  created () {
    // Load file
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getFile`, { id: this.id, filename: this.filename }).then(data => {
        this.content = data.content
        this.deletable = !data.meta.not_deletable
        this.$nextTick(() => {
          // Enable save button upon modification
          this.editor.on('change', (e) => { this.invalidForm = false })
        })
      })
    }
  },
  mounted () {
    if (this.parentNodes.length === 0) {
      // Find all parent DOM nodes
      let parentNode = this.$el.parentNode
      while (parentNode && 'classList' in parentNode) {
        this.parentNodes.push(parentNode)
        parentNode = parentNode.parentNode
      }
    }
    // Force all parent nodes to take 100% of the window height
    this.parentNodes.forEach(node => {
      node.classList.add('h-100')
    })

    window.addEventListener('resize', this.resizeEditor)
  },
  beforeDestroy () {
    // Remove height constraint on all parent nodes
    this.parentNodes.forEach(node => {
      node.classList.remove('h-100')
    })
    window.removeEventListener('resize', this.resizeEditor)
  }
}
</script>
