<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="source"
    :validation="$v.source"
    @validations="sourceValidations = $event"
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
        <span v-else>{{ $t('New {sourceClass} Authentication Source', { sourceClass: this.sourceClass}) }}</span>
      </h4>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.source.$touch()">
      <pf-button-save v-if="!isNew && !isClone" :disabled="invalidForm" :isLoading="isLoading">{{ $t('Save') }}</pf-button-save>
      <pf-button-save v-else-if="isClone" :disabled="invalidForm" :isLoading="isLoading">{{ $t('Clone') }}</pf-button-save>
      <pf-button-save v-else :disabled="invalidForm" :isLoading="isLoading">{{ $t('Create') }}</pf-button-save>
      <pf-button-delete v-if="!isNew && !isClone" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Source?')" @on-delete="remove()"/>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationAuthenticationSourcesViewFields as fields,
  pfConfigurationAuthenticationSourcesViewDefaults as defaults
} from '@/globals/pfConfiguration'
const { validationMixin } = require('vuelidate')

export default {
  name: 'AuthenticationSourcesView',
  mixins: [
    validationMixin,
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
    sourceClass: { // from router
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
      return this.$store.getters['$_sources/isLoading']
    },
    invalidForm () {
      return this.$v.source.$invalid || this.$store.getters['$_sources/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'sources' })
    },
    create () {
      this.$store.dispatch('$_sources/createAuthenticationSource', this.source).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch('$_sources/updateAuthenticationSource', this.source).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch('$_sources/deleteAuthenticationSource', this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_sources/getAuthenticationSource', this.id).then(data => {
        this.source = Object.assign({}, data)
      })
    }
  }
}
</script>
