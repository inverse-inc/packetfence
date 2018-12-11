<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="module"
    :vuelidate="$v.module"
    :isNew="isNew"
    :isClone="isClone"
    @validations="moduleValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Portal Module {id}', { id: strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Portal Module {id}', { id: strong(id) })"></span>
        <span v-else v-html="$t('New {moduleType} Portal Module', { moduleType: strong(moduleType) })"></span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="moduleType"></b-badge>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.module.$touch()">
      <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
        <icon v-if="ctrlKey" name="step-backward" class="mx-1"></icon>
        <template v-if="isNew">{{ $t('Create') }}</template>
        <template v-else-if="isClone">{{ $t('Clone') }}</template>
        <template v-else>{{ $t('Save') }}</template>
      </pf-button-save>
      <pf-button-delete v-if="!isNew && !isClone" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Module?')" @on-delete="remove()"/>
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
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import {
  pfConfigurationPortalModuleViewFields as fields,
  pfConfigurationPortalModuleViewDefaults as defaults
} from '@/globals/pfConfigurationPortalModules'
const { validationMixin } = require('vuelidate')

export default {
  name: 'PortalModuleView',
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
    moduleType: { // from router (or module)
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
      modules: [], // all modules
      module: defaults(this), // will be overloaded with the data from the store
      moduleValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      module: this.moduleValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.module.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    sources () {
      return fieldTypeValues[fieldType.SOURCE](this.$store)
    }
  },
  methods: {
    close (event) {
      this.$router.push({ name: 'portal_modules' })
    },
    strong (text) {
      return `<strong>${text}</strong>`
    },
    create (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createPortalModule`, this.module).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'portal_module', params: { id: this.module.id } })
        }
      })
    },
    save (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updatePortalModule`, this.module).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove (event) {
      this.$store.dispatch(`${this.storeName}/deletePortalModule`, this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getPortalModule`, this.id).then(data => {
        this.moduleType = data.type
        this.module = Object.assign({}, data)
        if (this.isClone) {
          this.module.id = null
        }
      })
    }
    this.module.type = this.moduleType
    this.$store.dispatch('config/getSources')
    this.$store.dispatch(`${this.storeName}/all`).then(data => {
      this.modules = data
    })
  }
}
</script>
