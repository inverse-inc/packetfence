<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :is-loading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :isNew="isNew"
    :isClone="isClone"
    :initial-tab-index="tabIndex"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <template v-if="!isNew && !isClone">
          <span v-html="$t('Remote Connection Profile {id}', { id: $strong(id) })"></span>
        </template>
        <span v-else-if="isClone" v-html="$t('Clone Remote Connection Profile {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Remote Connection Profile') }}</span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Remote Connection Profile?')" @on-delete="remove()"/>
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
} from '../_config/remoteConnectionProfile'

export default {
  name: 'remote-connection-profile-view',
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
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/remoteConnectionProfile
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_remote_connection_profiles/isLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
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
    },
    roles () {
      return this.$store.getters['config/rolesList']
    },
    files: { // mutating this property will re-evaluate view() and validators()
      get () {
        const { meta: { files = [] } = {} } = this
        return files
      },
      set (newValue) {
        this.$set(this.meta, 'files', newValue)
      }
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_remote_connection_profiles/options', this.id).then(options => {
        const { meta = {} } = options
        const { isNew, isClone, files, sortFiles, createDirectory, deleteFile } = this
        this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, files, sortFiles, createDirectory, deleteFile } })
        if (this.id) { // existing
          this.$store.dispatch('$_remote_connection_profiles/getRemoteConnectionProfile', this.id).then(form => {
            form = JSON.parse(JSON.stringify(form)) // dereference
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          })
        } else { // new
          this.$store.dispatch(`${this.formStoreName}/setForm`, defaults(meta)) // set defaults
        }
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'remote_connection_profiles' })
    },
    clone () {
      this.$router.push({ name: 'cloneRemoteConnectionProfile' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_remote_connection_profiles/createRemoteConnectionProfile', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'remote_connection_profile', params: { id: this.form.id } })
        }
      }).catch(this.notifyError)
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_remote_connection_profiles/updateRemoteConnectionProfile', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      }).catch(this.notifyError)
    },
    remove () {
      this.$store.dispatch('$_remote_connection_profiles/deleteRemoteConnectionProfile', this.id).then(() => {
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
    }
  },
  created () {
    this.$store.dispatch('$_bases/getGeneral')
    this.init()
  },
  watch: {
    id: {
      handler: function () {
        this.init()
      }
    },
    isClone: {
      handler: function () {
        this.init()
      }
    },
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
