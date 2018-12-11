<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="domain"
    :vuelidate="$v.domain"
    @validations="domainValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Domain') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Domain') }}</span>
      </h4>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.domain.$touch()">
      <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
      <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Domain?')" @on-delete="remove()"/>
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
} from '@/globals/pfConfigurationDomains'
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
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      domain: defaults(this), // will be overloaded with the data from the store
      domainValidations: {} // will be overloaded with data from the pfConfigView
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
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'domains' })
    },
    create () {
      this.$store.dispatch('$_domains/createDomain', this.domain).then(response => {
        this.close()
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
  }
}
</script>
