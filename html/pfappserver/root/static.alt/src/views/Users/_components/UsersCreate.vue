<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <h4 class="mb-0" v-t="'Create Users'"></h4>
<pre>{{ JSON.stringify(form, null, 2) }}</pre>
      </b-card-header>
      <b-tabs v-model="modeIndex" card>
        <b-tab title="Single">
<!--
          <b-form @submit.prevent="create()" @change="$v.$touch()">
-->
          <b-form @submit.prevent="create()">
            <b-form-row align-v="center">
              <b-col sm="12">
                <pf-form-range-toggle :column-label="$t('Username (PID) overwrite')"
                  :formStoreName="formStoreName" formNamespace="single.pid_overwrite"
                  :values="{checked: 1, unchecked: 0}"
                  :rightLabels="{checked: $t('Yes'), unchecked: $t('No')}"
                  :text="$t('Overwrite the username (PID) if it already exists.')"
                />
                <pf-form-input :column-label="$t('Username (PID)')"
                  :formStoreName="formStoreName" formNamespace="single.pid"
                  :text="$t('The username to use for login to the captive portal.')"
                />
                <pf-form-password :column-label="$t('Password')"
                  :formStoreName="formStoreName" formNamespace="single.password"
                  generate
                />
                <pf-form-input :column-label="$t('Login remaining')"
                  :formStoreName="formStoreName" formNamespace="single.login_remaining"
                  type="number"
                  :text="$t('Leave empty to allow unlimited logins.')"
                />
                <pf-form-input :column-label="$t('Email')"
                  :formStoreName="formStoreName" formNamespace="single.email"
                  type="email"
                />
                <pf-form-input :column-label="$t('Sponsor')"
                  :formStoreName="formStoreName" formNamespace="single.sponsor"
                  :text="$t('If no sponsor is defined the current user will be used.')"
                />
                <pf-form-input :column-label="$t('Language')"
                  :formStoreName="formStoreName" formNamespace="single.lang"
                />
                <pf-form-chosen :column-label="$t('Gender')"
                  :formStoreName="formStoreName" formNamespace="single.gender"
                  :placeholder="$t('Choose gender')"
                  :options="genders"
                  label="name" track-by="value"
                />
                <pf-form-input :column-label="$t('Title')"
                  :formStoreName="formStoreName" formNamespace="single.title"
                />
                <pf-form-input :column-label="$t('Firstna me')"
                  :formStoreName="formStoreName" formNamespace="single.firstname"
                />
                <pf-form-input :column-label="$t('Lastname')"
                  :formStoreName="formStoreName" formNamespace="single.lastname"
                />
                <pf-form-input :column-label="$t('Nickname')"
                  :formStoreName="formStoreName" formNamespace="single.nickname"
                />
                <pf-form-input :column-label="$t('Company')"
                  :formStoreName="formStoreName" formNamespace="single.company"
                />
                <pf-form-input :column-label="$t('Telephone number')"
                  :formStoreName="formStoreName" formNamespace="single.telephone"
                />
                <pf-form-input :column-label="$t('Cellphone number')"
                  :formStoreName="formStoreName" formNamespace="single.cell_phone"
                />
                <pf-form-input :column-label="$t('Workphone number')"
                  :formStoreName="formStoreName" formNamespace="single.work_phone"
                />
                <pf-form-input :column-label="$t('Apartment number')"
                  :formStoreName="formStoreName" formNamespace="single.apartment_number"
                />
                <pf-form-input :column-label="$t('Building Number')"
                  :formStoreName="formStoreName" formNamespace="single.building_number"
                />
                <pf-form-input :column-label="$t('Room Number')"
                  :formStoreName="formStoreName" formNamespace="single.room_number"
                />
                <pf-form-textarea :column-label="$t('Address')"
                  :formStoreName="formStoreName" formNamespace="single.address"
                  rows="4" max-rows="6"
                />
                <pf-form-datetime :column-label="$t('Anniversary')"
                  :formStoreName="formStoreName" formNamespace="single.anniversary"
                  :config="{datetimeFormat: 'YYYY-MM-DD'}"
                />
                <pf-form-datetime :column-label="$t('Birthday')"
                  :formStoreName="formStoreName" formNamespace="single.birthday"
                  :config="{datetimeFormat: 'YYYY-MM-DD'}"
                />
                <pf-form-input :column-label="$t('Psk')"
                  :formStoreName="formStoreName" formNamespace="single.psk"
                />
                <pf-form-textarea :column-label="$t('Notes')"
                  :formStoreName="formStoreName" formNamespace="single.notes"
                  rows="3" max-rows="3"
                />
                <pf-form-input :column-label="$t('Custom Field 1')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_1"
                />
                <pf-form-input :column-label="$t('Custom Field 2')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_2"
                />
                <pf-form-input :column-label="$t('Custom Field 3')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_3"
                />
                <pf-form-input :column-label="$t('Custom Field 4')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_4"
                />
                <pf-form-input :column-label="$t('Custom Field 5')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_5"
                />
                <pf-form-input :column-label="$t('Custom Field 6')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_6"
                />
                <pf-form-input :column-label="$t('Custom Field 7')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_7"
                />
                <pf-form-input :column-label="$t('Custom Field 8')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_8"
                />
                <pf-form-input :column-label="$t('Custom Field 9')"
                  :formStoreName="formStoreName" formNamespace="single.custom_field_9"
                />
              </b-col>
            </b-form-row>
          </b-form>
        </b-tab>
        <b-tab :title="$t('Multiple')" v-can:create-multiple="'users'">
          <pf-form-row>
            <b-alert show variant="info" v-html="$t('The usernames are constructed from the <b>prefix</b> and the <b>quantity</b>. For example, setting the prefix to <i>guest</i> and the quantity to <i>3</i> creates usernames <i>guest1</i>, <i>guest2</i> and <i>guest3</i>. Random passwords will be created.')"></b-alert>
          </pf-form-row>
          <b-form @submit.prevent="create()">
            <b-form-row align-v="center">
              <b-col sm="12">
                <pf-form-range-toggle :column-label="$t('Username (PID) overwrite')"
                  :formStoreName="formStoreName" formNamespace="multiple.pid_overwrite"
                  :values="{checked: 1, unchecked: 0}"
                  :rightLabels="{checked: $t('Overwrite'), unchecked: $t('Ignore')}"
                  :text="$t('Overwrite the username (PID) if it already exists.')"
                />
                <pf-form-input :column-label="$t('Username Prefix')"
                  :formStoreName="formStoreName" formNamespace="multiple.prefix"
                />
                <pf-form-input :column-label="$t('Quantity')"
                  :formStoreName="formStoreName" formNamespace="multiple.quantity"
                  type="number"
                />
                <pf-form-row :column-label="$t('Password')" align-v="start">
                  <b-row>
                    <b-col lg="9">
                      <b-row>
                        <b-col><b-form-input v-model="passwordOptions.pwlength" type="range" min="6" max="64"></b-form-input></b-col>
                        <b-col>{{ $t('{count} characters', { count: passwordOptions.pwlength }) }}</b-col>
                      </b-row>
                      <b-row>
                        <b-col><b-form-checkbox v-model="passwordOptions.upper">ABC</b-form-checkbox></b-col>
                        <b-col><b-form-checkbox v-model="passwordOptions.lower">abc</b-form-checkbox></b-col>
                        <b-col><b-form-checkbox v-model="passwordOptions.digits">123</b-form-checkbox></b-col>
                        <b-col><b-form-checkbox v-model="passwordOptions.special">!@#</b-form-checkbox></b-col>
                        <b-col><b-form-checkbox v-model="passwordOptions.brackets">({&lt;</b-form-checkbox></b-col>
                        <b-col><b-form-checkbox v-model="passwordOptions.high">äæ±</b-form-checkbox></b-col>
                        <b-col><b-form-checkbox v-model="passwordOptions.ambiguous">0Oo</b-form-checkbox></b-col>
                      </b-row>
                    </b-col>
                  </b-row>
                </pf-form-row>
                <pf-form-input :column-label="$t('Login remaining')"
                  :formStoreName="formStoreName" formNamespace="multiple.login_remaining"
                  type="number"
                  :text="$t('Leave empty to allow unlimited logins.')"
                />
                <pf-form-input :column-label="$t('Firstname')"
                  :formStoreName="formStoreName" formNamespace="multiple.firstname"
                />
                <pf-form-input :column-label="$t('Lastname')"
                  :formStoreName="formStoreName" formNamespace="multiple.lastname"
                />
                <pf-form-input :column-label="$t('Company')"
                  :formStoreName="formStoreName" formNamespace="multiple.company"
                />
                <pf-form-textarea :column-label="$t('Notes')"
                  :formStoreName="formStoreName" formNamespace="multiple.notes"
                  rows="3" max-rows="3"
                />
              </b-col>
            </b-form-row>
          </b-form>
        </b-tab>
      </b-tabs>

      <b-container class="card-body" fluid>
        <b-form-row>
          <b-col sm="12">

            <b-form-group label-cols="3" :label="$t('Registration Window')">
              <b-row>
                <b-col>
                  <pf-form-datetime
                    :formStoreName="formStoreName" formNamespace="common.valid_from"
                    :min="new Date()"
                    :config="{datetimeFormat: 'YYYY-MM-DD'}"
                  />
                </b-col>
                <p class="pt-2"><icon name="long-arrow-alt-right"></icon></p>
                <b-col>
                  <pf-form-datetime
                    :formStoreName="formStoreName" formNamespace="common.expiration"
                    :min="new Date()"
                    :config="{datetimeFormat: 'YYYY-MM-DD'}"
                  />
                </b-col>
              </b-row>
            </b-form-group>
            <pf-form-fields :column-label="$t('Actions')"
              :formStoreName="formStoreName" formNamespace="common.actions"
              :button-label="$t('Add Action')"
              :field="actionField"
              sortable
            ></pf-form-fields>
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

    <users-preview-modal v-model="showUsersPreviewModal" store-name="$_users"/>

  </div>
</template>

<script>
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormRow from '@/components/pfFormRow'
import pfFormTextarea from '@/components/pfFormTextarea'
import password from '@/utils/password'
import UsersPreviewModal from './UsersPreviewModal'
import {
  pfFieldType,
  pfFieldTypeValues
} from '@/globals/pfField'
import {
  createForm, createValidators,
  actions,
  passwordOptions
} from '../_config/'
import { format } from 'date-fns'

export default {
  name: 'users-create',
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormFields,
    pfFormInput,
    pfFormPassword,
    pfFormRangeToggle,
    pfFormRow,
    pfFormTextarea,
    UsersPreviewModal
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
      actionField: {
        component: pfFieldTypeValue,
        attrs: {
          typeLabel: this.$i18n.t('Select action type'),
          valueLabel: this.$i18n.t('Select action value'),
          fields: actions // ../_config/
        }
      },
      passwordOptions, // ../_config/
      genders: pfFieldTypeValues[pfFieldType.GENDER](),
      modeIndex: 0,
      showUsersPreviewModal: false
    }
  },
  computed: {
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    invalidSingleForm () {
      const { $invalid = false } = this.$store.getters[`${this.formStoreName}/$stateNS`]('single')
      return $invalid
    },
    invalidMultipleForm () {
      const { $invalid = false } = this.$store.getters[`${this.formStoreName}/$stateNS`]('multiple')
      return $invalid
    },
    invalidCommonForm () {
      const { $invalid = false } = this.$store.getters[`${this.formStoreName}/$stateNS`]('common')
      return $invalid
    },
    isLoading () {
      return this.$store.getters['$_users/isLoading']
    },
    invalidForm () {
      if (this.modeIndex === 0) { // single
        return this.invalidSingleForm || this.invalidCommonForm || this.isLoading
      } else { // multiple
        return this.invalidMultipleForm || this.invalidCommonForm || this.isLoading
      }
    },
    createdUsers () {
      return this.$store.state.$_users.createdUsers
    }
  },
  methods: {
    init () {
      // setup form store module
      this.$store.dispatch(`${this.formStoreName}/setForm`, createForm)
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, createValidators)
    },
    close () {
      this.$router.push({ name: 'users' })
    },
    create () {
      this.showUsersPreviewModal = false
      switch (this.modeIndex) {
        case 0: { // single
          const data = {
            ...this.form.single,
            ...this.form.common
          }
          this.$store.dispatch('$_users/createUser', data).then(() => {
            this.$store.dispatch('$_users/createPassword', Object.assign({ quiet: true }, data)).then(() => {
              this.$store.commit('$_users/CREATED_USERS_REPLACED', [data])
              this.showUsersPreviewModal = true
            })
          })
          break
        }
        case 1: { // multiple
          let createdUsers = []
          let promises = []
          const baseValue = {
            ...this.form.multiple,
            ...this.form.common,
            ...{ quiet: true }
          }
          for (let i = 0; i < this.form.multiple.quantity; i++) {
            const pid = this.form.multiple.prefix + (i + 1)
            const pwd = password.generate(this.passwordOptions)
            const currentData = {
              ...{ pid, password: pwd },
              ...baseValue
            }
            promises.push(this.$store.dispatch('$_users/exists', pid).then(() => {
              // user exists
              return this.$store.dispatch('$_users/updateUser', currentData).then(() => {
                return this.$store.dispatch('$_users/updatePassword', currentData).then(() => {
                  createdUsers.push(currentData)
                })
              })
            }).catch(() => {
              // user doesn't exist
              return this.$store.dispatch('$_users/createUser', currentData).then(() => {
                return this.$store.dispatch('$_users/createPassword', currentData).then(() => {
                  createdUsers.push(currentData)
                })
              })
            }))
          }
          Promise.all(promises).then(values => {
            this.$store.dispatch('notification/info', {
              message: this.$i18n.t('{quantity} users created', { quantity: values.length }),
              success: null,
              skipped: null,
              failed: null
            })
            this.$store.commit('$_users/CREATED_USERS_REPLACED', createdUsers)
            this.showUsersPreviewModal = true
          })
          break
        }
        default:
          // noop
      }
    }
  },
  mounted () {
    this.$store.dispatch('config/getAdminRoles')
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getTenants')
    this.$store.dispatch('config/getBaseGuestsAdminRegistration') // for access durations
    this.init()
  }
}
</script>
