<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="realm"
    :validation="$v.realm"
    @validations="realmValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Realm') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Realm') }}</span>
      </h4>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.realm.$touch()">
      <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
      <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Realm?')" @on-delete="remove()"/>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import { isFQDN } from '@/globals/pfValidators'
const { validationMixin } = require('vuelidate')
const { required, alphaNum } = require('vuelidate/lib/validators')

export default {
  name: 'RealmView',
  mixins: [
    validationMixin,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete,
    pfFormInput,
    pfFormSelect,
    pfFormTextarea,
    pfFormToggle
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
    return {
      domains: [],
      realm: { // will be overloaded with the data from the store
        id: null,
        portal_strip_username: 'enabled',
        admin_strip_username: 'enabled',
        radius_strip_username: 'enabled'
      },
      realmValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      realm: this.realmValidations
    }
  },
  computed: {
    isNew () {
      return this.id === null
    },
    isLoading () {
      return this.$store.getters['$_realms/isLoading']
    },
    invalidForm () {
      return this.$v.realm.$invalid || this.$store.getters['$_realms/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: [
          {
            if: this.isNew, // new realms only
            key: 'id',
            component: pfFormInput,
            label: this.$i18n.t('Realm'),
            validators: {
              [this.$i18n.t('Realm is required.')]: required,
              [this.$i18n.t('Alphanumeric value required.')]: alphaNum
            }
          },
          {
            key: 'options',
            component: pfFormTextarea,
            label: this.$i18n.t('Realm Options'),
            text: this.$i18n.t('You can add FreeRADIUS options in the realm definition.')
          },
          {
            key: 'domain',
            component: pfFormSelect,
            label: this.$i18n.t('Domain'),
            text: this.$i18n.t('The domain to use for the authentication in that realm.'),
            attrs: {
              options: this.domains
            }
          },
          {
            key: 'portal_strip_username',
            component: pfFormToggle,
            label: this.$i18n.t('Strip on the portal'),
            text: this.$i18n.t('Should the usernames matching this realm be stripped when used on the captive portal.'),
            attrs: {
              values: { checked: 'enabled', unchecked: 'disabled' }
            }
          },
          {
            key: 'admin_strip_username',
            component: pfFormToggle,
            label: this.$i18n.t('Strip on the admin'),
            text: this.$i18n.t('Should the usernames matching this realm be stripped when used on the administration interface.'),
            attrs: {
              values: { checked: 'enabled', unchecked: 'disabled' }
            }
          },
          {
            key: 'radius_strip_username',
            component: pfFormToggle,
            label: this.$i18n.t('Strip in RADIUS authorization'),
            text: this.$i18n.t('Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x. Note that this doesn\'t control the stripping in FreeRADIUS, use the options above for that.'),
            attrs: {
              values: { checked: 'enabled', unchecked: 'disabled' }
            }
          }
        ]
      }
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'realms' })
    },
    create () {
      this.$store.dispatch('$_realms/createRealm', this.realm).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch('$_realms/updateRealm', this.realm).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch('$_realms/deleteRealm', this.id).then(response => {
        this.close()
      })
    }
  },
  mounted () {
    this.$store.dispatch('$_domains/all').then(items => {
      this.domains = items.map(domain => domain.id)
      if (this.isNew && this.domains.length > 0) {
        this.realm.domain = this.domains[0]
      }
    })
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_realms/getRealm', this.id).then(data => {
        this.realm = Object.assign({}, data)
      })
    }
  }
}
</script>
