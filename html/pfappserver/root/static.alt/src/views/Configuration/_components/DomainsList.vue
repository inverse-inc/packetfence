<template>
  <div>
    <pf-config-list
      :config="config"
    >
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newDomain' }">{{ $t('New Domain') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
          <pf-empty-table :isLoading="state.isLoading">{{ $t('No domains found') }}</pf-empty-table>
      </template>
      <template slot="ntlm_cache" slot-scope="data">
        <icon name="circle" :class="{ 'text-success': data.ntlm_cache === 'enabled', 'text-danger': data.ntlm_cache !== 'enabled' }"
          v-b-tooltip.hover.left.d300 :title="$t(data.ntlm_cache)"></icon>
      </template>
      <template slot="joined" slot-scope="data">
        <template v-if="initTestDomainJoin(data)">
          <icon v-if="getTestDomainJoin(data) === null" name="circle-notch" class="text-secondary" spin></icon>
          <icon v-else-if="getTestDomainJoin(data) === true" name="circle" class="text-success"
            v-b-tooltip.hover.left.d300 :title="$t('Test join success.')"></icon>
          <icon v-else-if="getTestDomainJoin(data) === false" name="circle" class="text-danger"
            v-b-tooltip.hover.left.d300 :title="$t('Test join failed.')"></icon>
        </template>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Domain?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button v-if="canJoin(item)" size="sm" variant="outline-warning" class="mr-1" @click.stop.prevent="clickJoin(item)">{{ $t('Join') }}</b-button>
          <b-button v-if="canRejoin(item)" size="sm" variant="outline-warning" class="mr-1" @click.stop.prevent="clickRejoin(item)">{{ $t('Rejoin') }}</b-button>
          <b-button v-if="canUnjoin(item)" size="sm" variant="outline-warning" class="mr-1" @click.stop.prevent="clickUnjoin(item)">{{ $t('Unjoin') }}</b-button>
        </span>
      </template>
    </pf-config-list>
    <b-modal v-model="join.showInputModal" size="lg" centered id="joinModal" @shown="focusUsernameInput">
      <template slot="modal-title">
        <h4>{{ $t(`${join.type} {domain} Domain`, { domain: join.item.id }) }}</h4>
        <b-form-text v-t="$t('Please enter administrative credentials to connect to the domain.')" class="mb-0"></b-form-text>
      </template>
      <b-form-group class="mb-0">
        <pf-form-input ref="usernameInput" v-model="join.username" :column-label="$t('Username')"
          :vuelidate="$v.join.username"/>
        <pf-form-password ref="passwordInput" v-model="join.password" :column-label="$t('Password')"
          :vuelidate="$v.join.password"/>
      </b-form-group>
      <div slot="modal-footer" @mouseenter="$v.$touch()">
        <b-button variant="secondary" class="mr-1" @click="join.showInputModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="invalidForm" @click="clickModal()">{{ $t('{type} {domain}', { type: join.type, domain: join.item.id }) }}</b-button>
      </div>
    </b-modal>
    <b-modal v-model="join.showWaitModal" size="lg" centered id="waitModal" :hide-footer="true">
      <template slot="modal-title">
        <h4>{{ $t('Please wait') }}</h4>
        <b-form-text v-t="$t('This operation may take a few minutes.')" class="mb-0"></b-form-text>
      </template>
      <b-container class="my-5">
        <b-row class="justify-content-md-center text-secondary">
          <b-col cols="12" md="auto">
            <b-media>
              <icon name="circle-notch" scale="2" slot="aside" spin></icon>
              <h4>{{ $t(`${join.type}ing {domain} Domain`, { domain: join.item.id }) }}</h4>
              <p class="font-weight-light">{{ $t('Closing this dialog will not cancel the operation.') }}</p>
            </b-media>
          </b-col>
        </b-row>
      </b-container>
    </b-modal>
  </div>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  pfConfigurationDomainsListConfig as config
} from '@/globals/configuration/pfConfigurationDomains'
import {
  required
} from 'vuelidate/lib/validators'

const { validationMixin } = require('vuelidate')

export default {
  name: 'DomainsList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable,
    pfFormInput,
    pfFormPassword
  },
  mixins: [
    validationMixin
  ],
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      config: config(this),
      domainJoinTests: {},
      join: { // for 'Join', 'Unjoin' and 'Rejoin'
        type: null, // 'Join', 'Unjoin' or 'Rejoin'
        item: { id: null }, // domain object from pf-search
        username: null, // input from user
        password: null, // input from user
        showInputModal: false, // show use input
        showWaitModel: false, // show join progress
      }
    }
  },
  validations () {
    return {
      join: {
        username: {
          [this.$i18n.t('Username required.')]: required
        },
        password: {
          [this.$i18n.t('Password required.')]: required
        }
      }
    }
  },
  computed: {
    invalidForm () {
      return this.$v.join.$invalid
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneDomain', params: { id: item.id } })
    },
    resetModal () {
      this.$set(this.join, 'username', null)
      this.$set(this.join, 'password', null)
      this.$set(this.join, 'showInputModal', true)
      this.$v.$reset()
    },
    clickJoin (item) {
      this.$set(this.join, 'type', 'Join')
      this.$set(this.join, 'item', item)
      this.resetModal()
    },
    clickRejoin (item) {
      this.$set(this.join, 'type', 'Rejoin')
      this.$set(this.join, 'item', item)
      this.resetModal()
    },
    clickUnjoin (item) {
      this.$set(this.join, 'type', 'Unjoin')
      this.$set(this.join, 'item', item)
      this.resetModal()
    },
    clickModal () {
      const fn = this[`do${this.join.type}`]
      fn(this.join.item)
      this.$set(this.join, 'showInputModal', false)
    },
    doJoin (item) {
      this.$set(this.join, 'showWaitModal', true)
      this.$store.dispatch(`${this.storeName}/joinDomain`, { id: item.id, username: this.join.username, password: this.join.password }).then(response => {
      })
    },
    doRejoin (item) {
      this.$set(this.join, 'showWaitModal', true)
      this.$store.dispatch(`${this.storeName}/rejoinDomain`, { id: item.id, username: this.join.username, password: this.join.password }).then(response => {
      })
    },
    doUnjoin (item) {
      this.$set(this.join, 'showWaitModal', true)
      this.$store.dispatch(`${this.storeName}/unjoinDomain`, { id: item.id, username: this.join.username, password: this.join.password }).then(response => {
      })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteDomain`, item.id).then(response => {
        this.$router.go() // reload
      })
    },
    initTestDomainJoin (item) {
      if (!(item.id in this.domainJoinTests)) {
         this.$set(this.domainJoinTests, item.id, null)
      }
      this.$store.dispatch(`${this.storeName}/testDomain`, item.id).then(response => {
        this.$set(this.domainJoinTests, item.id, response)
      })
      return true
    },
    getTestDomainJoin (item) {
      return this.domainJoinTests[item.id]
    },
    canJoin (item) {
      return (item.id in this.domainJoinTests && this.domainJoinTests[item.id].status === false)
    },
    canRejoin (item) {
      return (item.id in this.domainJoinTests && this.domainJoinTests[item.id].status === true)
    },
    canUnjoin (item) {
      return (item.id in this.domainJoinTests && this.domainJoinTests[item.id].status === true)
    },
    focusUsernameInput () {
      this.$refs.usernameInput.focus()
    }
  }
}
</script>
