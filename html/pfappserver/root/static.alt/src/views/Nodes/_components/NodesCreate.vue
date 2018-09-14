<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Nodes'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-form @submit.prevent="create()">
        <b-form-row align-v="center">
          <b-col sm="8">
            <pf-form-input v-model="single.mac" :filter="globals.regExp.stringMac" :label="$t('MAC')" :validation="$v.single.mac" :invalid-feedback="$t(invalidMacFeedback)"/>
            <b-form-group horizontal label-cols="3" :label="$t('Owner')">
              <pf-autocomplete v-model="single.pid" placeholder="default" @search="searchUsers" :suggestions="matchingUsers"></pf-autocomplete>
            </b-form-group>
            <b-form-group horizontal label-cols="3" :label="$t('Status')">
              <b-form-select v-model="single.status" :options="statuses"></b-form-select>
            </b-form-group>
            <b-form-group horizontal label-cols="3" :label="$t('Role')">
              <b-form-select v-model="single.category" :options="roles"></b-form-select>
            </b-form-group>
            <b-form-group horizontal label-cols="3" :label="$t('Unregistration')">
              <pf-form-datetime v-model="single.unregdate" :moments="['1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"></pf-form-datetime>
            </b-form-group>
            <b-form-group horizontal label-cols="3" :label="$t('Notes')">
              <b-form-textarea v-model="single.notes" rows="8" max-rows="12"></b-form-textarea>
            </b-form-group>
          </b-col>
        </b-form-row>
      </b-form>
    </div>
    <b-card-footer @mouseenter="$v.$touch()">
      <b-button variant="primary" :disabled="invalidForm" @click="create()">
        <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Create') }}
      </b-button>
    </b-card-footer>

  </b-card>
</template>

<script>
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import pfFormInput from '@/components/pfFormInput'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfAutocomplete from '@/components/pfAutocomplete'
import draggable from 'vuedraggable'
import usersApi from '@/views/Users/_api'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'
// import { pfValidateMacAddressIsUnique as macAddressIsUnique } from '@/globals/pfValidators'
const { validationMixin } = require('vuelidate')
const { macAddress, required } = require('vuelidate/lib/validators')

export default {
  name: 'NodesCreate',
  components: {
    draggable,
    'pf-form-datetime': pfFormDatetime,
    'pf-form-input': pfFormInput,
    'pf-autocomplete': pfAutocomplete
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
      globals: {
        regExp: regExp
      },
      modeIndex: 0,
      single: {
        mac: '',
        status: 'reg'
      },
      matchingUsers: []
    }
  },
  validations: {
    single: {
      mac: {
        macAddress: macAddress(),
        required,
        isUnique (mac) {
          if (!this.$v.single.mac.macAddress) return true
          return this.$store.dispatch('$_nodes/exists', mac).then(results => {
            return false
          }).catch(() => {
            return true
          })
        }
      }
    },
    csv: {
      file: { required }
    }
  },
  computed: {
    statuses () {
      return conditionValues[conditionType.NODE_STATUS]
    },
    roles () {
      return this.$store.getters['config/rolesList']
    },
    isLoading () {
      return this.$store.getters['$_nodes/isLoading']
    },
    invalidMacFeedback () {
      if (!this.$v.single.mac.isUnique) {
        return 'MAC address already exists'
      }
      return 'Enter a valid MAC address'
    },
    invalidForm () {
      if (this.modeIndex === 0) {
        return this.$v.single.$invalid || this.isLoading
      } else {
        return false
      }
    }
  },
  methods: {
    searchUsers () {
      const _this = this
      let body = {
        limit: 10,
        fields: ['pid', 'firstname', 'lastname', 'email'],
        sort: ['pid'],
        query: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              {field: 'pid', op: 'contains', value: this.single.pid},
              {field: 'firstname', op: 'contains', value: this.single.pid},
              {field: 'lastname', op: 'contains', value: this.single.pid},
              {field: 'email', op: 'contains', value: this.single.pid}
            ]
          }]
        }
      }
      usersApi.search(body).then((data) => {
        _this.matchingUsers = data.items.map(item => item.pid)
      })
    },
    create () {
      if (this.modeIndex === 0) {
        this.$store.dispatch('$_nodes/createNode', this.single).then(response => {
          this.$store.dispatch('notification/info', {message: this.$i18n.t('Node') + ' ' + this.single.mac + ' ' + this.$i18n.t('created')})
          this.single = {
            mac: '',
            status: 'reg'
          }
        }).catch(err => {
          this.$store.dispatch('notification/danger', {message: this.$store.state[this.storeName].message})
          console.debug(err)
          console.debug(this.$store.state[this.storeName].message)
        })
      }
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
  }
}
</script>

