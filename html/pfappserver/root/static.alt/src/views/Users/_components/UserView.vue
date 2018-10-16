
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('User') }} <strong v-text="pid"></strong></h4>
      </b-card-header>

      <b-tabs card>

        <b-tab :title="$t('Profile')" active>
          <b-row>
            <b-col>
              <pf-form-input :column-label="$t('Username (PID)')"
                readonly
                v-model.trim="userContent.pid"
                :validation="$v.userContent.pid"
                text="The username to use for login to the captive portal."/>
              <pf-form-input :column-label="$t('Password')"
                v-model="userContent.password"
                :validation="$v.userContent.password"
                type="password"
                text="Leave empty to keep current password."/>
              <pf-form-input :column-label="$t('Login remaining')"
                v-model="userContent.login_remaining"
                :validation="$v.userContent.login_remaining"
                type="number"
                text="Leave empty to allow unlimited logins."/>
              <pf-form-input :column-label="$t('Email')"
                v-model.trim="userContent.email"
                :validation="$v.userContent.email"
              />
              <pf-form-input :column-label="$t('Sponsor')"
                v-model.trim="userContent.sponsor"
                :validation="$v.userContent.sponsor"
              />
              <pf-form-chosen :column-label="$t('Gender')"
                v-model="userContent.gender"
                label="text"
                track-by="value"
                :placeholder="$t('Choose gender')"
                :options="[{text:$t('Male'), value:'m'}, {text:$t('Female'), value:'f'}, {text:$t('Other'), value:'o'}]"
              ></pf-form-chosen>
              <pf-form-input :column-label="$t('Title')"
                v-model="userContent.title"
                :validation="$v.userContent.title"
              />
              <pf-form-input :column-label="$t('Firstname')"
                v-model="userContent.firstname"
                :validation="$v.userContent.firstname"
              />
              <pf-form-input :column-label="$t('Lastname')"
                v-model="userContent.lastname"
                :validation="$v.userContent.lastname"
              />
              <pf-form-input :column-label="$t('Nickname')"
                v-model="userContent.nickname"
                :validation="$v.userContent.nickname"
              />
              <pf-form-input :column-label="$t('Company')"
                v-model="userContent.company"
                :validation="$v.userContent.company"
              />
              <pf-form-input :column-label="$t('Telephone number')"
                v-model="userContent.telephone"
                :filter="globals.regExp.stringPhone"
                :validation="$v.userContent.telephone"
              />
              <pf-form-input :column-label="$t('Cellphone number')"
                v-model="userContent.cell_phone"
                :filter="globals.regExp.stringPhone"
                :validation="$v.userContent.cell_phone"
              />
              <pf-form-input :column-label="$t('Workphone number')"
                v-model="userContent.work_phone"
                :filter="globals.regExp.stringPhone"
                :validation="$v.userContent.work_phone"
              />
              <pf-form-input :column-label="$t('Apartment number')"
                v-model="userContent.apartment_number"
                :filter="globals.regExp.stringPhone"
                :validation="$v.userContent.apartment_number"
              />
              <pf-form-input :column-label="$t('Building Number')"
                v-model="userContent.building_number"
                :filter="globals.regExp.stringPhone"
                :validation="$v.userContent.building_number"
              />
              <pf-form-input :column-label="$t('Room Number')"
                v-model="userContent.room_number"
                :filter="globals.regExp.stringPhone"
                :validation="$v.userContent.room_number"
              />
              <pf-form-textarea :column-label="$t('Address')" rows="4" max-rows="6"
                v-model="userContent.address"
                :validation="$v.userContent.address"
              />
              <pf-form-datetime :column-label="$t('Anniversary')"
                v-model="userContent.anniversary"
                :config="{format: 'YYYY-MM-DD'}"
                :validation="$v.userContent.anniversary"
              />
              <pf-form-datetime :column-label="$t('Birthday')"
                v-model="userContent.birthday"
                :config="{format: 'YYYY-MM-DD'}"
                :validation="$v.userContent.birthday"
              />
              <pf-form-textarea :column-label="$t('Notes')"
                v-model="userContent.notes"
                :validation="$v.userContent.notes"
                rows="8" max-rows="12"
              />
            </b-col>
          </b-row>
        </b-tab>

        <b-tab :title="$t('Custom Fields')">
          <b-form-row>
            <b-col>
              <pf-form-input v-for="i in 9" v-model="userContent['custom_field_' + i]" :column-label="'Custom Field ' + i" :key="i"/>
            </b-col>
          </b-form-row>
        </b-tab>

      </b-tabs>

      <b-card-footer @mouseenter="$v.userContent.$touch()">
        <b-button class="mr-1" type="submit" variant="primary" :disabled="invalidForm"><icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Save') }}</b-button>
        <b-button variant="danger" :disabled="isLoading" @click="deleteUser()" v-t="'Delete'"></b-button>
      </b-card-footer>

    </b-card>
  </b-form>
</template>

<script>
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
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
  userExists
} from '@/globals/pfValidators'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'

const { validationMixin } = require('vuelidate')

export default {
  name: 'UserView',
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormTextarea,
    pfFormToggle
  },
  mixins: [
    validationMixin
  ],
  props: {
    pid: String
  },
  data () {
    return {
      globals: {
        regExp: regExp,
        schema: schema
      },
      userContent: {
        pid: '',
        email: '',
        sponsor: '',
        password: '',
        login_remaining: null,
        gender: '',
        title: '',
        firstname: '',
        lastname: '',
        nickname: '',
        company: '',
        telephone: '',
        cell_phone: '',
        work_phone: '',
        address: '',
        apartment_number: '',
        building_number: '',
        room_number: '',
        anniversary: '',
        birthday: '',
        notes: '',
        custom_field_1: '',
        custom_field_2: '',
        custom_field_3: '',
        custom_field_4: '',
        custom_field_5: '',
        custom_field_6: '',
        custom_field_7: '',
        custom_field_8: '',
        custom_field_9: ''
      }
    }
  },
  validations () {
    return {
      userContent: {
        pid: {
          [this.$i18n.t('Username required.')]: required,
          [this.$i18n.t('Username exists.')]: not(and(required, userExists, conditional(this.userContent.pid !== this.pid))),
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.pid)]: maxLength(schema.person.pid.maxLength)
        },
        email: {
          [this.$i18n.t('Email address required.')]: required,
          [this.$i18n.t('Invalid email address.')]: email,
          [this.$i18n.t('Maximum {maxLenth} characters.', schema.person.email)]: maxLength(schema.person.email.maxLength)
        },
        sponsor: {
          [this.$i18n.t('Invalid email address.')]: email,
          [this.$i18n.t('Maximum {maxLenth} characters.', schema.person.sponsor)]: maxLength(schema.person.sponsor.maxLength)
        },
        password: {
          [this.$i18n.t('Password must be at least 6 characters.')]: minLength(6)
        },
        login_remaining: {
          [this.$i18n.t('Must be numeric.')]: numeric,
          [this.$i18n.t('Must be greater than {min}.', schema.password.login_remaining)]: minValue(schema.password.login_remaining.min),
          [this.$i18n.t('Must be less than {max}.', schema.password.login_remaining)]: maxValue(schema.password.login_remaining.max)
        },
        title: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.title)]: maxLength(schema.person.title.maxLength)
        },
        firstname: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.firstname)]: maxLength(schema.person.firstname.maxLength)
        },
        lastname: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.lastname)]: maxLength(schema.person.lastname.maxLength)
        },
        nickname: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.nickname)]: maxLength(schema.person.lastname.maxLength)
        },
        company: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.company)]: maxLength(schema.person.company.maxLength)
        },
        telephone: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.telephone)]: maxLength(schema.person.telephone.maxLength)
        },
        cell_phone: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.cell_phone)]: maxLength(schema.person.cell_phone.maxLength)
        },
        work_phone: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.work_phone)]: maxLength(schema.person.work_phone.maxLength)
        },
        address: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.address)]: maxLength(schema.person.address.maxLength)
        },
        apartment_number: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.apartment_number)]: maxLength(schema.person.apartment_number.maxLength)
        },
        building_number: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.building_number)]: maxLength(schema.person.building_number.maxLength)
        },
        room_number: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.room_number)]: maxLength(schema.person.room_number.maxLength)
        },
        anniversary: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.anniversary)]: maxLength(schema.person.anniversary.maxLength)
        },
        birthday: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.birthday)]: maxLength(schema.person.birthday.maxLength)
        },
        notes: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.notes)]: maxLength(schema.person.notes.maxLength)
        },
        custom_field_1: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_1)]: maxLength(schema.person.custom_field_1.maxLength)
        },
        custom_field_2: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_2)]: maxLength(schema.person.custom_field_2.maxLength)
        },
        custom_field_3: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_3)]: maxLength(schema.person.custom_field_3.maxLength)
        },
        custom_field_4: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_4)]: maxLength(schema.person.custom_field_4.maxLength)
        },
        custom_field_5: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_5)]: maxLength(schema.person.custom_field_5.maxLength)
        },
        custom_field_6: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_6)]: maxLength(schema.person.custom_field_6.maxLength)
        },
        custom_field_7: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_7)]: maxLength(schema.person.custom_field_7.maxLength)
        },
        custom_field_8: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_8)]: maxLength(schema.person.custom_field_8.maxLength)
        },
        custom_field_9: {
          [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_9)]: maxLength(schema.person.custom_field_9.maxLength)
        }
      }
    }
  },
  computed: {
    node () {
      return this.$store.state.$_users.users[this.pid]
    },
    isLoading () {
      return this.$store.getters['$_users/isLoading']
    },
    invalidForm () {
      return this.$v.userContent.$invalid || this.$store.getters['$_users/isLoading']
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'users' })
    },
    save () {
      this.$store.dispatch('$_users/updateUser', this.userContent).then(response => {
        this.close()
      })
    },
    deleteUser () {
      this.$store.dispatch('$_users/deleteUser', this.pid).then(response => {
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
  mounted () {
    this.$store.dispatch('$_users/getUser', this.pid).then(data => {
      this.userContent = Object.assign({}, data)
    })
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>
