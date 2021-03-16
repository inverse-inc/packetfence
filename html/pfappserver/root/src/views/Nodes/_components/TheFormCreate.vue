<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Node'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-form @submit.prevent="create()">
        <b-form-row align-v="center">
          <b-col sm="12">
            <pf-form-input :column-label="$t('MAC')"
              :form-store-name="formStoreName" form-namespace="mac"
            />
            <pf-form-autocomplete :column-label="$t('Owner')"
              :form-store-name="formStoreName" form-namespace="pid"
              :suggestions="matchingUsers"
              placeholder="default"
              @search="searchUsers"
            />
            <pf-form-select :column-label="$t('Status')"
              :form-store-name="formStoreName" form-namespace="status"
              :options="statuses"
            />
            <pf-form-select :column-label="$t('Role')"
              :form-store-name="formStoreName" form-namespace="category_id"
              :options="roles"
            />
            <pf-form-datetime :column-label="$t('Unregistration')"
              :form-store-name="formStoreName" form-namespace="unregdate"
              :moments="['1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
            />
            <pf-form-textarea :column-label="$t('Notes')"
              :form-store-name="formStoreName" form-namespace="notes"
              rows="3" max-rows="3"
            />
          </b-col>
        </b-form-row>
      </b-form>
    </div>
    <b-card-footer>
      <b-button variant="primary" :disabled="disableForm" @click="create()">
        <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Create') }}
      </b-button>
    </b-card-footer>

  </b-card>
</template>

<script>
import pfFormAutocomplete from '@/components/pfFormAutocomplete'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import usersApi from '@/views/Users/_api'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'

import { form, createValidators } from '../_config/'

export default {
  name: 'the-view-create',
  components: {
    pfFormAutocomplete,
    pfFormDatetime,
    pfFormInput,
    pfFormSelect,
    pfFormTextarea
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      matchingUsers: []
    }
  },
  computed: {
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    disableForm () {
      return this.invalidForm || this.isLoading
    },
    statuses () {
      return conditionValues[conditionType.NODE_STATUS]
    },
    roles () {
      return this.$store.getters['session/allowedNodeRolesList']
    },
    isLoading () {
      return this.$store.getters['$_nodes/isLoading']
    }
  },
  methods: {
    init () {
      // setup form store module
      this.$store.dispatch(`${this.formStoreName}/setForm`, form)
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, createValidators)
    },
    create () {
      this.$store.dispatch('$_nodes/createNode', this.form).then(() => {
        this.init()
        this.close()
      })
    },
    close () {
      this.$router.push({ name: 'nodes' })
    },
    searchUsers () {
      let body = {
        limit: 10,
        fields: ['pid', 'firstname', 'lastname', 'email'],
        sort: ['pid'],
        query: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'pid', op: 'contains', value: this.form.pid },
              { field: 'firstname', op: 'contains', value: this.form.pid },
              { field: 'lastname', op: 'contains', value: this.form.pid },
              { field: 'email', op: 'contains', value: this.form.pid }
            ]
          }]
        }
      }
      usersApi.search(body).then((data) => {
        this.matchingUsers = data.items.map(item => item.pid)
      })
    }
  },
  created () {
    this.$store.dispatch('session/getAllowedNodeRoles')
    this.init()
  }
}
</script>
