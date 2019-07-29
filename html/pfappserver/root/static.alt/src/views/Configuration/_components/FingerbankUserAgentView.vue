<template>
  <pf-config-view
    :isLoading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    :isNew="isNew"
    :isClone="isClone"
    @validations="formValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Fingerbank User Agent {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Fingerbank User Agent {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Fingerbank User Agent') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="'local'"></b-badge>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Fingerbank User Agent?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import {
  pfConfigurationFingerbankUserAgentViewFields as fields
} from '@/globals/configuration/pfConfigurationFingerbank'
const { validationMixin } = require('vuelidate')

export default {
  name: 'fingerbank-user-agent-view',
  mixins: [
    validationMixin
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
      form: {}, // will be overloaded with the data from the store
      formValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      form: this.formValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isUserAgentsLoading`]
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters[`${this.storeName}/isUserAgentsWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.form && this.form.not_deletable)) {
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
      if (this.id) {
        // existing
        this.$store.dispatch(`${this.storeName}/getUserAgent`, this.id).then(form => {
          if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
          this.form = form
        })
      }
    },
    close () {
      this.$router.push({ name: 'fingerbankUserAgents' })
    },
    clone () {
      this.$router.push({ name: 'cloneFingerbankUserAgent' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch(`${this.storeName}/createUserAgent`, this.form).then(response => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'fingerbankUserAgent', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch(`${this.storeName}/updateUserAgent`, this.form).then(response => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch(`${this.storeName}/deleteUserAgent`, this.id).then(response => {
        this.close()
      })
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
