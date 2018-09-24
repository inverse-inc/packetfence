<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Users'"></h4>
    </b-card-header>
    <b-tabs v-model="modeIndex" card>
      <b-tab title="Single">
        <b-form @submit.prevent="create()">
          <b-form-row align-v="center">
            <b-col sm="8">
              <pf-form-toggle v-model="single.pid_overwrite" :column-label="$t('Username (PID) overwrite')" 
                :color="{checked: '#28a745', unchecked: '#dc3545'}" :values="{checked: 1, unchecked: 0}"
                text="Overwrite the username (PID) if it already exists."
                >{{ (single.pid_overwrite === 1) ? $t('Overwrite') : $t('Ignore') }}</pf-form-toggle>
              <pf-form-input v-model.trim="single.pid" :column-label="$t('Username (PID)')"
                :validation="$v.single.pid"
                :invalid-feedback="[
                  { [$t('Username required.')]: !$v.single.pid.required },
                  { [$t('This username already exists.')]: !$v.single.pid.userExists },
                  { [$t('Maximum {max} characters', {max: globals.schema.person.pid.maxLength})]: !$v.single.pid.maxLength }
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
                  { [$t('Maximum {max} characters', {max: globals.schema.person.email.maxLength})]: !$v.single.email.maxLength }
                ]"/>
              <pf-form-input v-model="single.firstname" :column-label="$t('Firstname')"
                :validation="$v.single.firstname"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters', {max: globals.schema.person.firstname.maxLength})]: !$v.single.firstname.maxLength }
                ]"
              />
              <pf-form-input v-model="single.lastname" :column-label="$t('Lastname')"
                :validation="$v.single.lastname"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters', {max: globals.schema.person.lastname.maxLength})]: !$v.single.lastname.maxLength }
                ]"
              />
              <pf-form-input v-model="single.company" :column-label="$t('Company')"
                :validation="$v.single.company"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters', {max: globals.schema.person.company.maxLength})]: !$v.single.company.maxLength }
                ]"
              />
              <pf-form-input v-model="single.telephone" :column-label="$t('Telephone')"
                :filter="globals.regExp.stringPhone"
                :validation="$v.single.telephone"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters', {max: globals.schema.person.telephone.maxLength})]: !$v.single.telephone.maxLength }
                ]"
              />
              <pf-form-textarea v-model="single.address" :column-label="$t('Address')" rows="4" max-rows="6"
                :validation="$v.single.address"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters', {max: globals.schema.person.address.maxLength})]: !$v.single.address.maxLength }
                ]"
              />
              <pf-form-textarea v-model="single.notes" :column-label="$t('Notes')" rows="8" max-rows="12"
                :validation="$v.single.notes"
                :invalid-feedback="[
                  { [$t('Maximum {max} characters', {max: globals.schema.person.notes.maxLength})]: !$v.single.notes.maxLength }
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
        <b-col sm="8">
          <b-form-group horizontal label-cols="3" :label="$t('Registration Window')">
            <b-form-row class="align-items-center">
              <b-col>
                <b-form-input type="date" v-model="valid_from"></b-form-input>
              </b-col>
              <icon name="arrow-right"></icon>
              <b-col>
                <b-form-input type="date" v-model="expiration"></b-form-input>
              </b-col>
            </b-form-row>
          </b-form-group>
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
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import draggable from 'vuedraggable'
import {
  required,
  email,
  minLength,
  maxLength
} from 'vuelidate/lib/validators'
import {
  and,
  not,
  conditional,
  userExists
} from '@/globals/pfValidators'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'

const { validationMixin } = require('vuelidate')

export default {
  name: 'UsersCreate',
  components: {
    draggable,
    'pf-form-input': pfFormInput,
    'pf-form-textarea': pfFormTextarea,
    'pf-form-toggle': pfFormToggle
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
      modeIndex: 0,
      single: {
        pid_overwrite: 0,
        pid: '',
        email: '',
        password: '',
        chosen: []
      },
      valid_from: new Date()
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
      }
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
        this.$store.dispatch('$_users/createUser', this.single).then(response => {
          // user created
        }).catch(err => {
          // noop
        })
      }
    }
  },
  created () {
    console.log(schema)
  }
}
</script>
