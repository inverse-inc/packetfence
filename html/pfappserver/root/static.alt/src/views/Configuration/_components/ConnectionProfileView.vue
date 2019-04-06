<template>
  <pf-config-view
    :is-loading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    :isNew="isNew"
    :isClone="isClone"
    :initialTabIndex="tabIndex"
    @validations="formValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <template v-if="!isNew && !isClone">
          <span v-html="$t('Connection Profile {id}', { id: $strong(id) })"></span>
          <b-button size="sm" variant="secondary" class="ml-2" :href="`/portal_preview/captive-portal?PORTAL=${id}`" target="_blank">{{ $t('Preview') }}</b-button>
        </template>
        <span v-else-if="isClone">{{ $t('Clone Connection Profile {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Connection Profile') }}</span>
      </h4>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-primary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Connection Profile?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationDefaultsFromMeta as defaults
} from '@/globals/configuration/pfConfiguration'
import {
  pfConfigurationConnectionProfileViewFields as fields
} from '@/globals/configuration/pfConfigurationConnectionProfiles'
const { validationMixin } = require('vuelidate')

export default {
  name: 'ConnectionProfileView',
  mixins: [
    validationMixin,
    pfMixinCtrlKey,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
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
    },
    tabIndex: { // from router
      type: Number,
      default: 0
    }
  },
  data () {
    return {
      form: {}, // will be overloaded with the data from the store
      formValidations: {}, // will be overloaded with data from the pfConfigView
      general: {},
      files: [],
      options: {}
    }
  },
  validations () {
    return {
      form: this.formValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    roles () {
      return this.$store.getters['config/rolesList']
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.form && this.form.not_deletable)) {
        return false
      }
      return true
    },
    keyLabelMap () {
      let keyLabelMap = {}
      this.getForm.fields.forEach(tab => {
        tab.fields.forEach(row => {
          row.fields.forEach(col => {
            if ('key' in col) keyLabelMap[col.key] = row.label
          })
        })
      })
      return keyLabelMap
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_bases/getGeneral').then(data => {
        this.general = data
      })
      if (this.id) {
        this.$store.dispatch(`${this.storeName}/files`, { id: this.id, sort: ['type', 'name'] }).then(data => {
          this.files = data.entries
        })
      }
      this.$store.dispatch(`${this.storeName}/options`, this.id).then(options => {
        this.options = options
        if (this.id) {
          // existing
          this.$store.dispatch(`${this.storeName}/getConnectionProfile`, this.id).then(form => {
            this.form = form
          })
        } else {
          // new
          this.form = defaults(options.meta) // set defaults
        }
      })
    },
    close () {
      this.$router.push({ name: 'connection_profiles' })
    },
    clone () {
      this.$router.push({ name: 'cloneConnectionProfile' })
    },
    create () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createConnectionProfile`, this.form).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'connection_profile', params: { id: this.form.id } })
        }
      }).catch(this.notifyError)
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateConnectionProfile`, this.form).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      }).catch(this.notifyError)
    },
    remove () {
      this.$store.dispatch(`${this.storeName}/deleteConnectionProfile`, this.id).then(response => {
        this.close()
      }).catch(this.notifyError)
    },
    notifyError (err) {
      const { response: { data: { errors = [] } } } = err
      errors.forEach((error) => {
        if (error.field in this.keyLabelMap) {
          error.field = this.$i18n.t(this.keyLabelMap[error.field])
        }
        let message = this.$i18n.t('Server Error - "{field}": {message}', error)
        this.$store.dispatch('notification/danger', { icon: 'server', url: `#${this.$route.fullPath}`, message: message })
      })
    },
    sortFiles (params) {
      let sort = [
        'type',
        params.sortDesc ? `${params.sortBy} DESC` : params.sortBy
      ]
      if (params.sortBy !== 'name') sort.push('name')
      this.$store.dispatch(`${this.storeName}/files`, { id: this.id, sort }).then(data => {
        this.files = data.entries
      })
    },
    createDirectory (items, path, name) {
      if (name) {
        items.push({ type: 'dir', name, size: 0, mtime: 0, path, entries: [] })
      }
    },
    deleteDirectory (path) {
      this.$store.dispatch(`${this.storeName}/deleteFile`, { id: this.id, filename: path })
    }
  },
  created () {
    this.init()
  },
  watch: {
    isClone: {
      handler: function (a, b) {
        this.init()
      }
    }
  }
}
</script>
