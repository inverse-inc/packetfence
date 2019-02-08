<template>
  <pf-config-view
    :is-loading="isLoading"
    :form="getForm"
    :model="connectionProfile"
    :vuelidate="$v.connectionProfile"
    :isNew="isNew"
    :isClone="isClone"
    :initialTabIndex="tabIndex"
    @validations="connectionProfileValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Connection Profile {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Connection Profile {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Connection Profile') }}</span>
      </h4>
      <pre>{{ JSON.stringify(connectionProfile, null, 2) }}</pre>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.connectionProfile.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save &amp; Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
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
  pfConfigurationConnectionProfileViewFields as fields,
  pfConfigurationConnectionProfileViewDefaults as defaults
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
      connectionProfile: defaults(this), // will be overloaded with the data from the store
      connectionProfileValidations: {}, // will be overloaded with data from the pfConfigView
      sources: [],
      billingTiers: [],
      provisionings: [],
      scans: [],
      general: {},
      files: []
    }
  },
  validations () {
    return {
      connectionProfile: this.connectionProfileValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.connectionProfile.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
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
      if (this.isNew || this.isClone || ('not_deletable' in this.connectionProfile && this.connectionProfile.not_deletable)) {
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
    close () {
      this.$router.push({ name: 'connection_profiles' })
    },
    create () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createConnectionProfile`, this.connectionProfile).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'connection_profile', params: { id: this.connectionProfile.id } })
        }
      }).catch(this.notifyError)
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateConnectionProfile`, this.connectionProfile).then(response => {
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

    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getConnectionProfile`, this.id).then(data => {
        this.connectionProfile = { ...this.connectionProfile, ...data }
      })
      this.$store.dispatch(`${this.storeName}/files`, { id: this.id, sort: ['type', 'name'] }).then(data => {
        this.files = data.entries
      })
    }
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('$_sources/all').then(data => {
      this.sources = data
    })
    this.$store.dispatch('$_billing_tiers/all').then(data => {
      this.billingTiers = data
    })
    this.$store.dispatch('$_provisionings/all').then(data => {
      this.provisionings = data
    })
    this.$store.dispatch('$_scans/allScanEngines').then(data => {
      this.scans = data
    })
    this.$store.dispatch('$_bases/getGeneral').then(data => {
      this.general = data
    })
  }
}
</script>
