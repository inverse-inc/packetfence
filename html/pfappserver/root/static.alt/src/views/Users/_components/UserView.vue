
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('User') }} {{ pid }}</h4>
      </b-card-header>

      <b-tabs card>

        <b-tab :title="$t('Profile')" active>
          <b-row>
            <b-col>
              <pf-form-input v-model="user.email" label="Email"
                :validation="$v.user.email" invalid-feedback="Must be a valid email address"/>
              <pf-form-input v-model="user.firstname" label="Firstname"/>
              <pf-form-input v-model="user.lastname" label="Lastname"/>
              <pf-form-input v-model="user.company" label="Company"/>
              <pf-form-input v-model="user.telephone" label="Telephone"/>
              <b-form-group horizontal label-cols="3" :label="$t('Notes')">
                <b-form-textarea v-model="user.notes" rows="4" max-rows="6"></b-form-textarea>
              </b-form-group>
            </b-col>
            <b-col>
              <pf-form-input v-model="user.anniversary" label="Anniversary" type="date"/>
              <pf-form-input v-model="user.birthday" label="Birthday" type="date"/>
              <pf-form-input v-model="user.gender" label="Gender"/>
            </b-col>
          </b-row>
        </b-tab>

        <b-tab :title="$t('Custom Fields')">
          <b-form-row>
            <b-col cols="6">
              <pf-form-input v-for="i in 9" v-model="user['custom_field_' + i]" :label="'custom_field_' + i" :key="i"/>
            </b-col>
          </b-form-row>
        </b-tab>

      </b-tabs>

      <b-card-footer align="right" @mouseenter="$v.user.$touch()">
        <b-button variant="outline-danger" class="mr-1" v-t="'Delete'"></b-button>
        <b-button type="submit" variant="primary" :disabled="$v.user.$invalid" v-t="'Save'"></b-button>
      </b-card-footer>

    </b-card>
  </b-form>
</template>

<script>
  import ToggleButton from '@/components/ToggleButton'
  import pfFormInput from '@/components/pfFormInput'
  const { validationMixin } = require('vuelidate')
  const { required, email } = require('vuelidate/lib/validators')

  export default {
    name: 'UserView',
    components: {
      'toggle-button': ToggleButton,
      'pf-form-input': pfFormInput
    },
    mixins: [
      validationMixin
    ],
    props: {
      pid: String
    },
    data () {
      return {
        user: {
          // Must at least define all fields that require validation
          email: '',
          notes: ''
        }
      }
    },
    validations: {
      user: {
        email: { email, required }
      }
    },
    methods: {
      close () {
        this.$router.push({ name: 'users' })
      },
      save () {
        this.$store.dispatch('$_users/updateUser', this.user)
      },
      onKeyup (event) {
        switch (event.keyCode) {
          case 27: // escape
            this.close()
        }
      }
    },
    mounted () {
      this.$store.dispatch('$_users/getUser', this.pid).then(data => {
        Object.assign(this.user, data)
      })
      document.addEventListener('keyup', this.onKeyup)
    },
    beforeDestroy () {
      document.removeEventListener('keyup', this.onKeyup)
    }
  }
</script>
