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
              <pf-form-input v-model.trim="single.pid" label="Username"
                :validation="$v.single.pid"
                invalid-feedback="This username already exists."
                text="The username to use for login to the captive portal."/>
              <pf-form-input type="password" v-model="single.password" label="Password"
                :validation="$v.single.password"
                invalid-feedback="The password must be at least 6 characters."
                text="Leave it empty if you want to generate a random password."/>
              <pf-form-input v-model.trim="single.email" label="Email"
                :validation="$v.single.email"
                invalid-feedback="Specify a valid email address."/>
              <pf-form-input v-model="single.firstname" label="Firstname"/>
              <pf-form-input v-model="single.lastname" label="Lastname"/>
              <pf-form-input v-model="single.company" label="Company"/>
              <pf-form-input v-model="single.telephone" label="Telephone"/>
              <b-form-group horizontal label-cols="3" :label="$t('Address')">
                <b-form-textarea v-model="single.address" rows="4" max-rows="6"></b-form-textarea>
              </b-form-group>
            </b-col>
            <b-col sm="4">
              <b-form-textarea :placeholder="$t('Notes')" v-model="single.notes" rows="8" max-rows="12"></b-form-textarea>
            </b-col>
          </b-form-row>
        </b-form>
      </b-tab>
      <b-tab :title="$t('Multiple')" v-can:create-multiple="'users'">
      </b-tab>
      <b-tab :title="$t('Import')" v-can:create-multiple="'users'">
        <b-form>
          <b-form-group horizontal label-cols="3" label="CSV File">
            <b-form-file v-model="csv.file" accept="text/*" choose-label="Choose a file" required></b-form-file>
          </b-form-group>
          <b-form-group horizontal label-cols="3" label="Column Delimiter">
            <b-form-select v-model="csv.delimiter" :options="csv.delimiters"></b-form-select>
          </b-form-group>
          <b-form-group horizontal label-cols="3" label="Default Voice Over IP">
            <b-form-checkbox v-model="csv.voip" value="yes"></b-form-checkbox>
          </b-form-group>
          <b-row>
            <b-col sm="3">{{ $t('Columns Order') }}</b-col>
            <b-col>
              <draggable v-model="csv.columns" :options="{ handle: '.draggable-handle' }">
                <div class="draggable-item" v-for="(column, index) in csv.columns" :key="column.name">
                  <span class="draggable-handle">{{ index }}</span>
                  <b-form-checkbox v-model="column.value" value="1">{{column.text}}</b-form-checkbox>
                </div>
              </draggable>
            </b-col>
          </b-row>
        </b-form>
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

    <b-card-footer align="right" @mouseenter="$v.$touch()">
      <b-button variant="outline-primary" :disabled="invalidForm" @click="create()">
        <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Create') }}
      </b-button>
    </b-card-footer>

  </b-card>
</template>

<script>
  import pfFormInput from '@/components/pfFormInput'
  import draggable from 'vuedraggable'
  const { validationMixin } = require('vuelidate')
  const { required, email, minLength } = require('vuelidate/lib/validators')

  export default {
    name: 'UsersCreate',
    components: {
      draggable,
      'pf-form-input': pfFormInput
    },
    mixins: [
      validationMixin
    ],
    data () {
      return {
        modeIndex: 0,
        single: {
          pid: '',
          email: '',
          password: ''
        },
        csv: {
          file: null,
          delimiter: 'comma',
          delimiters: [
            { value: 'comma', text: 'Comma' },
            { value: 'semicolon', text: 'Semicolon' },
            { value: 'tab', text: 'Tab' }
          ],
          voip: null,
          columns: [
            { value: '1', name: 'mac', text: 'MAC Address' },
            { value: '0', name: 'owner', text: 'Owner' },
            { value: '0', name: 'role', text: 'Role' },
            { value: '0', name: 'unregdate', text: 'Unregistration Date' }
          ]
        },
        valid_from: new Date()
      }
    },
    validations: {
      single: {
        pid: { required },
        email: { email, required },
        password: { minLength: minLength(6) }
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
            console.debug('user created')
          }).catch(err => {
            console.debug(err)
            console.debug(this.$store.state.$_users.message)
          })
        }
      }
    }
  }
  </script>
