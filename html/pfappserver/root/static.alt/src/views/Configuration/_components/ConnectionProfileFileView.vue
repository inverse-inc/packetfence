<template>
  <b-form class="h-100" @submit.prevent="save($event)">
    <b-card class="h-100" no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <b-form-row align-v="start">
          <h4 class="my-2">
            <router-link class="mr-1" :to="{ name: 'connectionProfileFiles', id }">{{ $t('Connection Profile {id}', { id: id }) }}</router-link>
            <span>/ {{ path }}</span>
            <b-button size="sm" variant="secondary" class="ml-2" :href="`/config/profile/${id}/preview/${filename}`" target="_blank">
              {{ $t('Preview') }} <icon class="ml-1" name="external-link-alt"></icon>
            </b-button>
          </h4>
          <b-form-group
            class="col col-md-4 ml-2 my-0"
            v-if="isNew"
            :invalid-feedback="invalidFeedbackFilename"
            :state="validFilename">
            <b-form-input size="lg" :placeholder="$t('Filename')" :state="validFilename" v-model.trim="$v.newFilename.$model"></b-form-input>
          </b-form-group>
        </b-form-row>
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
          <ace-editor v-model="content" theme="cobalt" lang="html" :height="editorHeight" @init="initEditor"></ace-editor>
        </div>
      </div>
      <b-card-footer @mouseenter="isNew && $v.newFilename.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="!invalidForm && isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="deletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete file?')" @on-delete="remove($event, true)"/>
        <pf-button-delete v-else-if="revertible" class="ml-1" :disabled="isLoading" :confirm="$t('Discard changes?')" @on-delete="remove($event)">{{ $t('Revert') }}</pf-button-delete>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import aceEditor from 'vue2-ace-editor'
import pfFormToggle from '@/components/pfFormToggle'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import { isFilenameWithExtension } from '@/globals/pfValidators'
const { validationMixin } = require('vuelidate')
const { required } = require('vuelidate/lib/validators')

export default {
  name: 'connection-profile-file-view',
  mixins: [
    validationMixin
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
    },
    isNew: { // from router
      type: Boolean
    }
  },
  data () {
    return {
      newFilename: '',
      deletable: false,
      revertible: false,
      content: '',
      contentModified: false,
      showLines: true,
      editor: null,
      editorHeight: '0px',
      variables: [ 'logo', 'username', 'user_agent', 'device_class', 'last_switch', 'last_port', 'last_vlan', 'last_connection_type', 'last_ssid' ],
      parentNodes: []
    }
  },
  validations: {
    newFilename: {
      required,
      isFilenameWithExtension: isFilenameWithExtension(['html', 'mjml']),
      isUnique (value) {
        return this.$store.dispatch(`${this.storeName}/getFile`, {
          id: this.id,
          filename: [this.filename, this.newFilename].join('/'),
          quiet: true
        }).then(() => false, () => true)
      }
    }
  },
  computed: {
    path () {
      let p = this.filename.split('/').join(' / ')
      if (p && this.isNew) p += ' / '
      return p
    },
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoadingFiles`]
    },
    validFilename () {
      return this.$v.newFilename.$dirty ? !this.$v.newFilename.$invalid : null
    },
    invalidFeedbackFilename () {
      if (this.$v.newFilename.required === false) {
        return this.$i18n.t('Filename required.')
      } else if (this.$v.newFilename.isFilenameWithExtension === false) {
        return this.$i18n.t('Alphanumeric characters only. Extension must be .html or .mjml')
      } else if (this.$v.newFilename.isUnique === false) {
        return this.$i18n.t('File already exists.')
      }
    },
    invalidForm () {
      return this.isNew ? this.$v.newFilename.$invalid : !this.contentModified
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    },
    windowSize () {
      return this.$store.getters['events/windowSize']
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'connectionProfileFiles', params: { id: this.id } })
    },
    init () {
      return this.$store.dispatch(`${this.storeName}/getFile`, { id: this.id, filename: this.filename }).then(data => {
        this.content = data.content
        this.deletable = !data.meta.not_deletable
        this.revertible = !data.meta.not_revertible
        this.$nextTick(() => {
          this.contentModified = false
        })
        return data
      })
    },
    initEditor (instance) {
      // Load ACE editor extensions
      require('brace/ext/language_tools')
      require('brace/mode/html')
      require('brace/theme/cobalt')
      this.editor = instance
      this.editor.setAutoScrollEditorIntoView(true)
      this.$nextTick(() => {
        this.resizeEditor()
      })
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
      const actionKey = this.actionKey
      const action = this.deletable || this.revertible ? 'update' : 'create'
      let params = {
        id: this.id,
        filename: this.filename,
        content: this.content
      }
      if (this.isNew) params.filename += '/' + this.newFilename
      this.$store.dispatch(`${this.storeName}/${action}File`, params).then(response => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          if (this.isNew) {
            this.deletable = true
            this.isNew = false
            this.filename += '/' + this.newFilename
          } else {
            this.revertible = true
          }
          this.contentModified = false
        }
      })
    },
    remove ($event, close) {
      this.$store.dispatch(`${this.storeName}/deleteFile`, { id: this.id, filename: this.filename }).then(response => {
        if (close) {
          this.close()
        } else {
          this.init()
        }
      })
    }
  },
  created () {
    if (!this.isNew) {
      // Load file
      this.init().then(() => {
        this.$nextTick(() => {
          // Enable save button upon modification
          this.editor.on('change', (e) => { this.contentModified = true })
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
  },
  beforeDestroy () {
    // Remove height constraint on all parent nodes
    this.parentNodes.forEach(node => {
      node.classList.remove('h-100')
    })
  },
  watch: {
    escapeKey (pressed) {
      if (pressed) this.close()
    },
    windowSize: {
      handler: function (a, b) {
        if (a.clientWidth !== b.clientWidth || a.clientHeight !== b.clientHeight) {
          this.resizeEditor()
        }
      },
      deep: true
    }
  }
}
</script>
