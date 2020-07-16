<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :isNew="isNew"
    :isClone="isClone"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Authentication Source {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Authentication Source {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Authentication Source') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="sourceType"></b-badge>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1 mr-3" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove()"/>
        <template v-if="samlMetaData">
          <b-button class="ml-1 mr-1" size="sm" variant="outline-secondary" @click="showSamlMetaDataModal = true">{{ $t('View Service Provider Metadata') }}</b-button>
          <b-modal v-model="showSamlMetaDataModal" title="Service Provider Metadata" size="lg" centered cancel-disabled>
            <b-form-textarea ref="samlMetaDataTextarea" v-model="samlMetaData" :rows="27" :max-rows="27" readonly></b-form-textarea>
            <template v-slot:modal-footer>
              <b-button variant="secondary" class="mr-1" @click="showSamlMetaDataModal = false">{{ $t('Close') }}</b-button>
              <b-button variant="primary" @click="copySamlMetaData">{{ $t('Copy to Clipboard') }}</b-button>
            </template>
          </b-modal>
        </template>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import {
  defaultsFromMeta as defaults
} from '../_config/'
import {
  view,
  validators
} from '../_config/authenticationSource'

export default {
  name: 'authentication-source-view',
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    },
    sourceType: { // from router (or source)
      type: String,
      default: null
    },
    isNew: { // from router
      type: Boolean,
      default: false
    },
    isClone: { // from router
      type: Boolean,
      default: false
    },
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      samlMetaData: false, // will be overloaded with data from the store
      showSamlMetaDataModal: false
    }
  },
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/authenticationSource
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_sources/isLoading']
    },
    isDeletable () {
      const { isNew, isClone, form: { not_deletable: notDeletable = false } = {} } = this
      if (isNew || isClone || notDeletable) {
        return false
      }
      return true
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.formStoreName}/clearForm`)
      this.$store.dispatch(`${this.formStoreName}/clearMeta`)
      this.samlMetaData = false
      if (this.id) {
        // existing
        this.$store.dispatch('$_sources/optionsById', this.id).then(options => {
          this.$store.dispatch('$_sources/getAuthenticationSource', this.id).then(form => {
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
            const sourceType = form.type
            const { meta = {} } = options
            const { isNew, isClone, isDeletable } = this
            this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, isDeletable, sourceType } })
            if (form.type === 'SAML') {
              this.$store.dispatch('$_sources/getAuthenticationSourceSAMLMetaData', this.id).then(xml => {
                this.samlMetaData = xml
              })
            }
          })
        })
      } else {
        // new
        this.$store.dispatch('$_sources/optionsBySourceType', this.sourceType).then(options => {
          const { meta = {} } = options
          const { isNew, isClone, isDeletable, sourceType } = this
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, isDeletable, sourceType } })
          this.$store.dispatch(`${this.formStoreName}/setForm`, { ...defaults(meta), ...{ type: sourceType } }) // set defaults
        })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close (event) {
      this.$router.push({ name: 'sources' })
    },
    clone () {
      this.$router.push({ name: 'cloneAuthenticationSource' })
    },
    create (event) {
      const actionKey = this.actionKey
      this.$store.dispatch('$_sources/createAuthenticationSource', this.form).then(response => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'source', params: { id: this.form.id } })
        }
      })
    },
    save (event) {
      const actionKey = this.actionKey
      this.$store.dispatch('$_sources/updateAuthenticationSource', this.form).then(response => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove (event) {
      this.$store.dispatch('$_sources/deleteAuthenticationSource', this.id).then(response => {
        this.close()
      })
    },
    copySamlMetaData () {
      if (document.queryCommandSupported('copy')) {
        this.$refs.samlMetaDataTextarea.$el.select()
        document.execCommand('copy')
        this.showSamlMetaDataModal = false
        this.$store.dispatch('notification/info', { message: this.$i18n.t('XML copied to clipboard') })
      }
    }
  },
  created () {
    this.init()
  },
  watch: {
    id: {
      handler: function (a, b) {
        this.init()
      }
    },
    isClone: {
      handler: function (a, b) {
        this.init()
      }
    },
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
