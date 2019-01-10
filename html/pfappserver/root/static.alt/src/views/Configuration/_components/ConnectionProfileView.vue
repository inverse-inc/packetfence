<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="connectionProfile"
    :vuelidate="$v.connectionProfile"
    :isNew="isNew"
    :isClone="isClone"
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
} from '@/globals/pfConfigurationConnectionProfiles'
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
      general: {}
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
            if ('key' in col) keyLabelMap[col.key] = this.$i18n.t(row.label)
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
        error.field = this.keyLabelMap[error.field] || error.field
        let message = this.$i18n.t('Server Error - "{field}": {message}', error)
        this.$store.dispatch('notification/danger', { icon: 'server', url: `#${this.$route.fullPath}`, message: message })
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getConnectionProfile`, this.id).then(data => {
        this.connectionProfile = Object.assign({}, data)
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
    this.$store.dispatch('$_scans/all').then(data => {
      this.scans = data
    })
    this.$store.dispatch('$_bases/getBase', 'general').then(data => {
      this.general = data
    })
  }
}
</script>
