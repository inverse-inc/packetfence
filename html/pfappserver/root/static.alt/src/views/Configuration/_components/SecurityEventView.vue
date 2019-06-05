<template>
  <pf-config-view
    :is-loading="isLoading"
    :disabled="isLoading"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    :is-new="isNew"
    :is-clone="isClone"
    @validations="formValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Security Event {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Security Event {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Security Event') }}</span>
      </h4>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.form.$touch()">
      <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
      <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Security Event?')" @on-delete="remove()"/>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import {
  pfConfigurationDefaultsFromMeta as defaults
} from '@/globals/configuration/pfConfiguration'
import {
  pfConfigurationSecurityEventViewFields as fields
} from '@/globals/configuration/pfConfigurationSecurityEvents'
const { validationMixin } = require('vuelidate')

export default {
  name: 'SecurityEventView',
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
      formValidations: {}, // will be overloaded with data from the pfConfigView
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
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    }
  },
  methods: {
    init () {
      let promise
      if (this.id) {
        // existing
        promise = this.$store.dispatch(`${this.storeName}/getSecurityEvent`, this.id).then(form => {
          if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
          this.form = form
          return form
        })
      } else {
        promise = Promise.resolve()
      }
      promise.then(form => {
        this.$store.dispatch(`${this.storeName}/options`).then(options => {
          // store options
          this.options = options
          if (form) {
            this.form = form
          } else {
            // new
            this.form = defaults(options.meta) // set defaults
          }
          // make sure actions is an array
          if (!this.form.actions) {
            this.form.actions = []
          }
        })
      })
    },
    close () {
      this.$router.back()
    },
    create () {
      this.$store.dispatch(`${this.storeName}/createSecurityEvent`, this.form).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch(`${this.storeName}/updateSecurityEvent`, this.form).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch(`${this.storeName}/deleteSecurityEvent`, this.id).then(response => {
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
