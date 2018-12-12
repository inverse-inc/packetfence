<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="source"
    :vuelidate="$v.source"
    :isNew="isNew"
    :isClone="isClone"
    @validations="setValidations($event)"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Authentication Source {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Authentication Source {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New {sourceType} Authentication Source', { sourceType: this.sourceType}) }}</span>
      </h4>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save &amp; Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove()"/>
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
  pfConfigurationAuthenticationSourceViewFields as fields,
  pfConfigurationAuthenticationSourceViewDefaults as defaults
} from '@/globals/pfConfigurationAuthenticationSources'
const { validationMixin } = require('vuelidate')

export default {
  name: 'AuthenticationSourcesView',
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
      realms: [], // all realms
      sources: [], // all sources
      source: defaults(this), // will be overloaded with the data from the store
      sourceValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      source: this.sourceValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    }
  },
  methods: {
    close (event) {
      this.$router.push({ name: 'sources' })
    },
    create (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createAuthenticationSource`, this.source).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'source', params: { id: this.source.id } })
        }
      })
    },
    save (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateAuthenticationSource`, this.source).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove (event) {
      this.$store.dispatch(`${this.storeName}/deleteAuthenticationSource`, this.id).then(response => {
        this.close()
      })
    },
    setValidations (validations) {
      this.$set(this, 'sourceValidations', validations)
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getAuthenticationSource`, this.id).then(data => {
        this.sourceType = data.type
        this.source = Object.assign({}, data)
        if (this.isClone) {
          this.source.id = null
        }
      })
    }
    this.source.type = this.sourceType
    this.$store.dispatch('$_sources/all').then(data => {
      this.sources = data
    })
    this.$store.dispatch('$_realms/all').then(data => {
      this.realms = data
    })
  }
}
</script>
