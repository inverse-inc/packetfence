<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="domain"
    :vuelidate="$v.domain"
    :isNew="isNew"
    :isClone="isClone"
    @validations="domainValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Domain {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Domain {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Domain') }}</span>
      </h4>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.domain.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else>{{ $t('Save and Join') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Domain?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationDomainViewFields as fields,
  pfConfigurationDomainViewDefaults as defaults
} from '@/globals/configuration/pfConfigurationDomains'
const { validationMixin } = require('vuelidate')

export default {
  name: 'DomainView',
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
      domain: defaults(this), // will be overloaded with the data from the store
      domainValidations: {}, // will be overloaded with data from the pfConfigView
      sources: []
    }
  },
  validations () {
    return {
      domain: this.domainValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_domains/isLoading']
    },
    invalidForm () {
      return this.$v.domain.$invalid || this.$store.getters['$_domains/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.domain && this.domain.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'domains' })
    },
    create () {
      this.$store.dispatch('$_domains/createDomain', this.domain).then(response => {
        this.$router.push({ name: 'domain', params: { id: this.domain.id } })
      })
    },
    save () {
      this.$store.dispatch('$_domains/updateDomain', this.domain).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch('$_domains/deleteDomain', this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_domains/getDomain', this.id).then(data => {
        this.domain = Object.assign({}, data)
      })
    }
    this.$store.dispatch('$_sources/all').then(data => {
      this.sources = data
    })
  }
}
</script>
