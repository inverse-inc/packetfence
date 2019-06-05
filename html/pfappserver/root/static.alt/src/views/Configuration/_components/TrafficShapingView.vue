<template>
  <pf-config-view
    :isLoading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    :isNew="isNew"
    @validations="formValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew" v-html="$t('Traffic Shaping Policy {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Traffic Shaping Policy') }}</span>
      </h4>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Traffic Shaping Policy?')" @on-delete="remove()"/>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
      </b-card-footer>
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
  pfConfigurationTrafficShapingPolicyViewFields as fields
} from '@/globals/configuration/pfConfigurationTrafficShapingPolicies'
const { validationMixin } = require('vuelidate')

export default {
  name: 'TrafficShapingView',
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
    id: { // from router
      type: String,
      default: null
    },
    role: { // from router
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
    isDeletable () {
      if (this.isNew || ('not_deletable' in this.form && this.form.not_deletable)) {
        return false
      }
      return true
    },
    ctrlKey () {
      return this.$store.getters['events/ctrlKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/options`, this.id).then(options => {
        this.options = options
        if (this.id) {
          // existing
          this.$store.dispatch(`${this.storeName}/getTrafficShapingPolicy`, this.id).then(form => {
            this.form = form
          })
        } else {
          // new
          this.form = defaults(options.meta) // set defaults
          this.form.id = this.role // set id from role
        }
      })
    },
    close () {
      this.$router.push({ name: 'traffic_shapings' })
    },
    create () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createTrafficShapingPolicy`, this.form).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'traffic_shaping', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateTrafficShapingPolicy`, this.form).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch(`${this.storeName}/deleteTrafficShapingPolicy`, this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    this.init()
  },
  watch: {
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
