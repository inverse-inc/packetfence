
<template>
  <b-form>
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('User') }} {{ pid }}</h4>
      </b-card-header>
      <b-card-body>
        <b-tabs card>

          <b-tab :title="$t('Profile')" active>
            <b-row>
              <b-col>
                <pf-form-input v-model="user.email" :label="$t('Email')"
                  :validation="$v.user.email" :invalid-feedback="$t('Must be a valid email address')"/>
                <pf-form-input v-model="user.firstname" :label="$t('Firstname')"/>
                <pf-form-input v-model="user.lastname" :label="$t('Lastname')"/>
                <pf-form-input v-model="user.company" :label="$t('Company')"/>
                <pf-form-input v-model="user.telephone" :label="$t('Telephone')"/>
                <b-form-group horizontal label-cols="3" :label="$t('Notes')">
                  <b-form-textarea v-model="user.notes" :rows="4" :max-rows="6"></b-form-textarea>
                </b-form-group>
              </b-col>
              <b-col>
                <pf-form-input v-model="user.anniversary" :label="$t('Anniversary')" type="date"/>
                <pf-form-input v-model="user.birthday" :label="$t('Birthday')" type="date"/>
                <pf-form-input v-model="user.gender" :label="$t('Gender')"/>
              </b-col>
            </b-row>
          </b-tab>

        </b-tabs>
      </b-card-body>
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
        email: ''
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
    }
  },
  mounted () {
    this.$store.dispatch('$_users/getUser', this.pid).then(data => {
      Object.assign(this.user, data)
    })
  }
}
</script>

