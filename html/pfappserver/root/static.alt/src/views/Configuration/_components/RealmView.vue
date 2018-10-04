
<template>
  <b-form @submit.prevent="isNew? create() : save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">
          <span v-if="id">{{ $t('Realm') }} <strong v-text="id"></strong></span>
          <span v-else>{{ $t('New Realm') }}</span>
        </h4>
      </b-card-header>
      <div class="card-body">
        <pf-form-input v-if="isNew" v-model="realm.id"
          :column-label="$t('Realm')"
          :validation="$v.realm.id"/>
        <pf-form-textarea v-model="realm.options"
          :column-label="$t('Realm Options')"
          :text="$t('You can add FreeRADIUS options in the realm definition')"/>
        <pf-form-select v-model="realm.domain"
          :column-label="$t('Domain')"
          :options="domains"
          :text="$t('The domain to use for the authentication in that realm')"/>
        <pf-form-toggle v-model="realm.portal_strip_username"
          :column-label="$t('Strip on the portal')"
          :values="{ checked: 'enabled', unchecked: 'disabled' }"
          :text="$t('Should the usernames matching this realm be stripped when used on the captive portal')"/>
        <pf-form-toggle v-model="realm.admin_strip_username"
          :column-label="$t('Strip on the admin')"
          :values="{ checked: 'enabled', unchecked: 'disabled' }"
          :text="$t('Should the usernames matching this realm be stripped when used on the administration interface')"/>
        <pf-form-toggle v-model="realm.admin_strip_username"
          :column-label="$t('Strip in RADIUS authorization')"
          :values="{ checked: 'enabled', unchecked: 'disabled' }"
          :text="$t('Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x. Note that this doesn\'t control the stripping in FreeRADIUS, use the options above for that.')"/>
      </div>
      <b-card-footer @mouseenter="$v.realm.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
        <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Realm?')" @on-delete="deleteRealm()"/>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormToggle from '@/components/pfFormToggle'
import pfFormRow from '@/components/pfFormRow'
const { validationMixin } = require('vuelidate')
const { required, alphaNum } = require('vuelidate/lib/validators')

export default {
  name: 'RealmView',
  components: {
    pfButtonSave,
    pfButtonDelete,
    pfFormRow,
    pfFormInput,
    pfFormTextarea,
    pfFormSelect,
    pfFormToggle
  },
  mixins: [
    validationMixin
  ],
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
      }
    }
  },
  validations: {
    realm: {
      id: { required, alphaNum }
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
    deleteRealm () {
      this.$store.dispatch('$_realms/deleteRealm', this.id).then(response => {
        this.close()
      })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_realms/getRealm', this.id).then(data => {
        this.realm = Object.assign({}, data)
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
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>
