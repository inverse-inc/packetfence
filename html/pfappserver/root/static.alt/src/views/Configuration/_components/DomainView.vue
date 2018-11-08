<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="domain"
    :validation="$v.domain"
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
import pfFormInput from '@/components/pfFormInput'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import { isFQDN } from '@/globals/pfValidators'
const { validationMixin } = require('vuelidate')
const { required, alphaNum } = require('vuelidate/lib/validators')

export default {
  name: 'DomainView',
  mixins: [
    validationMixin,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete,
    pfFormInput
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    let self = this
    return {
      domain: { // will be overloaded with the data from the store
        id: null,
        ad_server: '%h'
      },
      domainValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      domain: this.domainValidations
    }
  },
  computed: {
    isNew () {
      return this.id === null
    },
    isLoading () {
      return this.$store.getters['$_domains/isLoading']
    },
    invalidForm () {
      return this.$v.domain.$invalid || this.$store.getters['$_domains/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: [
          {
            if: this.isNew, // new domains only
            key: 'id',
            component: pfFormInput,
            label: this.$i18n.t('Identifier'),
            text: this.$i18n.t('Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain.'),
            validators: {
              [this.$i18n.t('Name is required.')]: required,
              [this.$i18n.t('Alphanumeric value required.')]: alphaNum
            }
          },
          {
            key: 'workgroup',
            component: pfFormInput,
            label: this.$i18n.t('Workgroup'),
            validators: {
              [this.$i18n.t('Workgroup is required.')]: required
            }
          },
          {
            key: 'dns_name',
            component: pfFormInput,
            label: this.$i18n.t('DNS name of the domain'),
            text: this.$i18n.t('The DNS name (FQDN) of the domain.'),
            validators: {
              [this.$i18n.t('DNS name is required.')]: required,
              [this.$i18n.t('Fully Qualified Domain Name required.')]: isFQDN
            }
          },
          {
            key: 'server_name',
            component: pfFormInput,
            label: this.$i18n.t('This server\'s name'),
            text: this.$i18n.t('This server\'s name (account name) in your Active Directory. Use \'%h\' to automatically use this server hostname.'),
            validators: {
              [this.$i18n.t('Server name is required.')]: required
            }
          },
          {
            key: 'sticky_dc',
            component: pfFormInput,
            label: this.$i18n.t('Sticky DC'),
            text: this.$i18n.t('This is used to specify a sticky domain controller to connect to. If not specified, default \'*\' will be used to connect to any available domain controller.'),
            validators: {
              [this.$i18n.t('Sticky DC is required.')]: required
            }
          },
          {
            key: 'ad_server',
            component: pfFormInput,
            label: this.$i18n.t('Active Directory server'),
            text: this.$i18n.t('The IP address or DNS name of your Active Directory server.'),
            validators: {
              [this.$i18n.t('Active Directory server is required.')]: required
            }
          },
          {
            key: 'bind_dn',
            component: pfFormInput,
            label: this.$i18n.t('Username'),
            text: this.$i18n.t('The username of a Domain Admin to use to join the server to the domain.')
          },
          {
            key: 'bind_pass',
            component: pfFormInput,
            label: this.$i18n.t('Password'),
            text: this.$i18n.t('The password of a Domain Admin to use to join the server to the domain. Will not be stored permanently and is only used while joining the domain.'),
            attrs: {
              type: 'password'
            }
          }
        ]
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
