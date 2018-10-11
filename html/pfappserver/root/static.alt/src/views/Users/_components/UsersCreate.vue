<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Users'"></h4>
    </b-card-header>
    <b-tabs v-model="modeIndex" card>
      <b-tab title="Single">
        <b-form @submit.prevent="create()">
          <b-form-row align-v="center">
            <b-col sm="12">
              <pf-form-toggle v-model="single.pid_overwrite" :column-label="$t('Username (PID) overwrite')"
                :values="{checked: 1, unchecked: 0}" text="Overwrite the username (PID) if it already exists."
                >{{ (single.pid_overwrite === 1) ? $t('Overwrite') : $t('Ignore') }}</pf-form-toggle>
              <pf-form-input v-model.trim="single.pid" :column-label="$t('Username (PID)')"
                :validation="$v.single.pid"
                :invalid-feedback="[
                  { [$t('Username required.')]: !$v.single.pid.required },
                  { [$t('This username already exists.')]: !$v.single.pid.userExists },
                  { [$t('Maximum {max} characters.', {max: globals.schema.person.pid.maxLength})]: !$v.single.pid.maxLength }
                ]"
                text="The username to use for login to the captive portal."/>
              <pf-form-input type="password" v-model="single.password" :column-label="$t('Password')"
                :validation="$v.single.password"
                :invalid-feedback="[
                  { [$t('The password must be at least 6 characters.')]: !$v.single.password.minLength }
                ]"
                text="Leave it empty if you want to generate a random password."/>
              <pf-form-input v-model.trim="single.email" :column-label="$t('Email')"
                :validation="$v.single.email"
                :invalid-feedback="[
                  { [$t('Email address required.')]: !$v.single.email.required },
                  { [$t('Specify a valid email address.')]: !$v.single.email.email },
                  { [$t('Maximum {max} characters.', {max: globals.schema.person.email.maxLength})]: !$v.single.email.maxLength }
                ]"/>
              <pf-form-input v-model="single.firstname" :column-label="$t('Firstname')"
                :validation="$v.single.firstname"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters.', {max: globals.schema.person.firstname.maxLength})]: !$v.single.firstname.maxLength }
                ]"
              />
              <pf-form-input v-model="single.lastname" :column-label="$t('Lastname')"
                :validation="$v.single.lastname"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters.', {max: globals.schema.person.lastname.maxLength})]: !$v.single.lastname.maxLength }
                ]"
              />
              <pf-form-input v-model="single.company" :column-label="$t('Company')"
                :validation="$v.single.company"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters.', {max: globals.schema.person.company.maxLength})]: !$v.single.company.maxLength }
                ]"
              />
              <pf-form-input v-model="single.telephone" :column-label="$t('Telephone')"
                :filter="globals.regExp.stringPhone"
                :validation="$v.single.telephone"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters.', {max: globals.schema.person.telephone.maxLength})]: !$v.single.telephone.maxLength }
                ]"
              />
              <pf-form-textarea v-model="single.address" :column-label="$t('Address')" rows="4" max-rows="6"
                :validation="$v.single.address"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters.', {max: globals.schema.person.address.maxLength})]: !$v.single.address.maxLength }
                ]"
              />
              <pf-form-textarea v-model="single.notes" :column-label="$t('Notes')" rows="8" max-rows="12"
                :validation="$v.single.notes"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters.', {max: globals.schema.person.notes.maxLength})]: !$v.single.notes.maxLength }
                ]"
              />

            </b-col>
          </b-form-row>
        </b-form>
      </b-tab>
      <b-tab :title="$t('Multiple')" v-can:create-multiple="'users'">
      </b-tab>
    </b-tabs>

    <b-container class="card-body" fluid>
      <b-form-row>
        <b-col sm="12">

          <b-form-group horizontal label-cols="3" :label="$t('Registration Window')">
            <b-form-row class="align-text-top">
              <b-col>
                <pf-form-datetime v-model="valid_from"
                  :min="new Date()"
                  :config="{format: 'YYYY-MM-DD'}"
                  :validation="$v.valid_from"
                  :invalid-feedback="[
                    { [$t('Start date required.')]: !$v.valid_from.required },
                    { [$t('Date must be today or later.')]: !$v.valid_from.isGreaterThanEqualToday },
                    { [$t('Date must be less than or equal to end date.')]: !$v.valid_from.isLessThanEqualExpiration }
                  ]"
                />
              </b-col>
              <icon name="long-arrow-alt-right" class="m-2"></icon>
              <b-col>
                <pf-form-datetime v-model="expiration"
                  :min="new Date()"
                  :config="{format: 'YYYY-MM-DD'}"
                  :validation="$v.expiration"
                  :invalid-feedback="[
                    { [$t('End date required.')]: !$v.expiration.required },
                    { [$t('Date must be today or later.')]: !$v.expiration.isGreaterThanEqualToday },
                    { [$t('Date must be greater than or equal to start date.')]: !$v.expiration.isGreaterThanEqualValidFrom }
                  ]"
                />
              </b-col>
            </b-form-row>
          </b-form-group>

          <pf-form-sortable-fields
            sortable
            v-model="actions"
            column-label="Actions"
            :fields="actionFields"
            :validation="$v.actions"
            :invalid-feedback="[
              { [$t('One or more errors exist.')]: !$v.actions.anyError }
            ]"
            @validations="actionsValidations = $event"
          ></pf-form-sortable-fields>

        </b-col>
        <b-col sm="4"></b-col>
      </b-form-row>
    </b-container>

    <b-card-footer @mouseenter="$v.$touch()">
      <b-button variant="primary" :disabled="invalidForm" @click="create()">
        <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Create') }}
      </b-button>
    </b-card-footer>
  </b-card>
</template>

<script>
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormSortableFields from '@/components/pfFormSortableFields'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'

import {
  required,
  email,
  minLength,
  maxLength,
  minValue,
  maxValue,
  numeric
} from 'vuelidate/lib/validators'
import {
  and,
  not,
  conditional,
  compareDate,
  isDateFormat,
  userExists,
  requireAllSiblingFieldTypes,
  requireAnySiblingFieldTypes,
  restrictAllSiblingFieldTypes,
  limitSiblingFieldTypes
} from '@/globals/pfValidators'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import bytes from '@/utils/bytes'

const { validationMixin } = require('vuelidate')

export default {
  name: 'UsersCreate',
  components: {
    pfFormDatetime,
    pfFormInput,
    pfFormSortableFields,
    pfFormTextarea,
    pfFormToggle
  },
  mixins: [
    validationMixin
  ],
  data () {
    return {
      globals: {
        regExp: regExp,
        schema: schema
      },
      actionFields: [
        {
          value: 'set_access_duration',
          text: this.$i18n.t('Access duration'),
          types: [fieldType.DURATION],
          validators: {
            type: {
              /* Require "set_role" */
              [this.$i18n.t('Action requires "Set Role".')]: requireAllSiblingFieldTypes('set_role'),
              /* Restrict "set_unreg_date" */
              [this.$i18n.t('Action conflicts with "Unregistration date".')]: restrictAllSiblingFieldTypes('set_unreg_date'),
              /* Don't allow elsewhere */
              [this.$i18n.t('Action already exists.')]: limitSiblingFieldTypes(0)
            },
            value: {
              [this.$i18n.t('Value required.')]: required
            }
          }
        },
        {
          value: 'set_access_level',
          text: this.$i18n.t('Access level'),
          types: [fieldType.ADMINROLE],
          validators: {
            type: {
              /* Don't allow elsewhere */
              [this.$i18n.t('Action already exists.')]: limitSiblingFieldTypes(0)
            },
            value: {
              [this.$i18n.t('Value required.')]: required
            }
          }
        },
        {
          value: 'set_bandwidth_balance',
          text: this.$i18n.t('Bandwidth balance'),
          types: [fieldType.PREFIXMULTIPLIER],
          validators: {
            type: {
              /* Don't allow elsewhere */
              [this.$i18n.t('Action already exists.')]: limitSiblingFieldTypes(0)
            },
            value: {
              [this.$i18n.t('Value required.')]: required,
              [this.$i18n.t('Value must be greater than {min}bytes.', { min: bytes.toHuman(schema.node.bandwidth_balance.min) })]: minValue(schema.node.bandwidth_balance.min),
              [this.$i18n.t('Value must be less than {max}bytes.', { max: bytes.toHuman(schema.node.bandwidth_balance.max) })]: maxValue(schema.node.bandwidth_balance.max)
            }
          }
        },
        {
          value: 'mark_as_sponsor',
          text: this.$i18n.t('Mark as sponsor'),
          types: [fieldType.NONE],
          validators: {
            type: {
              /* Don't allow elsewhere */
              [this.$i18n.t('Action already exists.')]: limitSiblingFieldTypes(0)
            }
          }
        },
        {
          value: 'set_role',
          text: this.$i18n.t('Role'),
          types: [fieldType.ROLE],
          validators: {
            type: {
              /* When "Role" is selected, either "Time Balance" or "set_unreg_date" is required */
              [this.$i18n.t('Action requires either "Access duration" or "Unregistration date".')]: requireAnySiblingFieldTypes('set_access_duration', 'set_unreg_date'),
              /* Don't allow elsewhere */
              [this.$i18n.t('Action already exists.')]: limitSiblingFieldTypes(0)
            },
            value: {
              [this.$i18n.t('Value required.')]: required
            }
          }
        },
        {
          value: 'set_tenant_id',
          text: this.$i18n.t('Tenant ID'),
          types: [fieldType.TENANT],
          validators: {
            type: {
              /* Don't allow elsewhere */
              [this.$i18n.t('Action already exists.')]: limitSiblingFieldTypes(0)
            },
            value: {
              [this.$i18n.t('Value required.')]: required,
              [this.$i18n.t('Value must be numeric.')]: numeric
            }
          }
        },
        {
          value: 'set_time_balance',
          text: this.$i18n.t('Time balance'),
          types: [fieldType.DURATION],
          validators: {
            type: {
              /* Don't allow elsewhere */
              [this.$i18n.t('Action already exists.')]: limitSiblingFieldTypes(0)
            },
            value: {
              [this.$i18n.t('Value required.')]: required
            }
          }
        },
        {
          value: 'set_unreg_date',
          text: this.$i18n.t('Unregistration date'),
          types: [fieldType.DATETIME],
          moments: ['1 days', '1 weeks', '1 months', '1 years'],
          validators: {
            type: {
              /* Require "set_role" */
              [this.$i18n.t('Action requires "Set Role".')]: requireAllSiblingFieldTypes('set_role'),
              /* Restrict "set_access_duration" */
              [this.$i18n.t('Action conflicts with "Access duration".')]: restrictAllSiblingFieldTypes('set_access_duration'),
              /* Don't allow elsewhere */
              [this.$i18n.t('Action already exists.')]: limitSiblingFieldTypes(0)
            },
            value: {
              [this.$i18n.t('Future value required.')]: compareDate('>=', new Date(), schema.node.unregdate.format, false),
              [this.$i18n.t('Invalid date.')]: isDateFormat(schema.node.unregdate.format)
            }
          }
        }
      ],
      modeIndex: 0,
      single: {
        pid_overwrite: 0,
        pid: '',
        email: '',
        password: ''
      },
      valid_from: null,
      expiration: null,
      actions: null,
      actionsValidations: {}
    }
  },
  validations () {
    return {
      single: {
        pid: {
          required,
          userExists: not(and(required, userExists, conditional(!this.single.pid_overwrite))),
          maxLength: maxLength(schema.person.pid.maxLength)
        },
        email: {
          email,
          required,
          maxLength: maxLength(schema.person.email.maxLength)
        },
        password: { minLength: minLength(6) },
        firstname: { maxLength: maxLength(schema.person.firstname.maxLength) },
        lastname: { maxLength: maxLength(schema.person.lastname.maxLength) },
        company: { maxLength: maxLength(schema.person.company.maxLength) },
        telephone: { maxLength: maxLength(schema.person.telephone.maxLength) },
        address: { maxLength: maxLength(schema.person.address.maxLength) },
        notes: { maxLength: maxLength(schema.person.notes.maxLength) }
      },
      valid_from: {
        required: conditional(!!this.valid_from && this.valid_from !== '0000-00-00'),
        isGreaterThanEqualToday: compareDate('>=', new Date(), 'YYYY-MM-DD'),
        isLessThanEqualExpiration: not(and(required, conditional(this.valid_from), not(compareDate('<=', this.expiration, 'YYYY-MM-DD'))))
      },
      expiration: {
        required: conditional(!!this.expiration && this.expiration !== '0000-00-00'),
        isGreaterThanEqualToday: compareDate('>=', new Date(), 'YYYY-MM-DD'),
        isGreaterThanEqualValidFrom: not(and(required, conditional(this.expiration), not(compareDate('>=', this.valid_from, 'YYYY-MM-DD'))))
      },
      actions: this.actionsValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_users/isLoading']
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
    create () {
      if (this.modeIndex === 0) {
        this.$store.dispatch('$_users/createUser', this.single)
      }
    }
  },
  created () {
    this.$store.dispatch('config/getAdminRoles')
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getTenants')
  }
}
</script>
