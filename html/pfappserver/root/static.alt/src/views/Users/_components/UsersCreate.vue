<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <h4 class="mb-0" v-t="'Create Users'"></h4>
      </b-card-header>
      <b-tabs v-model="modeIndex" card>
        <b-tab title="Single">
          <b-form @submit.prevent="create()">
            <b-form-row align-v="center">
              <b-col sm="12">
                <pf-form-range-toggle :column-label="$t('Username (PID) overwrite')"
                  :form-store-name="formStoreName" form-namespace="single.pid_overwrite"
                  :values="{checked: 1, unchecked: 0}"
                  :rightLabels="{checked: $t('Yes'), unchecked: $t('No')}"
                  :text="$t('Overwrite the username (PID) if it already exists.')"
                />
                <!--- pid w/ domain_name -->
                <pf-form-input v-if="domainName" :column-label="$t('Username (PID)')"
                  :form-store-name="formStoreName" form-namespace="single.pid"
                  :text="$t('The username to use for login to the captive portal. The tenants domain_name will be appended to the username.')"
                >
                  <template v-slot:append>
                    <b-button disabled variant="link" v-b-tooltip.hover.top.d300 :title="$t('Domain Name will be appended.')">{{ domainName }}</b-button>
                  </template>
                </pf-form-input>
                <!-- pid wo/ domain_name -->
                <pf-form-input v-else :column-label="$t('Username (PID)')"
                  :form-store-name="formStoreName" form-namespace="single.pid"
                  :text="$t('The username to use for login to the captive portal.')"
                />
                <pf-form-password :column-label="$t('Password')"
                  :form-store-name="formStoreName" form-namespace="single.password"
                  generate
                />
                <pf-form-input :column-label="$t('Login remaining')"
                  :form-store-name="formStoreName" form-namespace="single.login_remaining"
                  type="number"
                  :text="$t('Leave empty to allow unlimited logins.')"
                />
                <pf-form-input :column-label="$t('Email')"
                  :form-store-name="formStoreName" form-namespace="single.email"
                  type="email"
                />
                <pf-form-input :column-label="$t('Sponsor')"
                  :form-store-name="formStoreName" form-namespace="single.sponsor"
                  :text="$t('If no sponsor is defined the current user will be used.')"
                  :placeholder="$store.state['session'].username"
                />
                <pf-form-input :column-label="$t('Language')"
                  :form-store-name="formStoreName" form-namespace="single.lang"
                />
                <pf-form-chosen :column-label="$t('Gender')"
                  :form-store-name="formStoreName" form-namespace="single.gender"
                  :placeholder="$t('Choose gender')"
                  :options="genders"
                  label="text" track-by="value"
                />
                <pf-form-input :column-label="$t('Title')"
                  :form-store-name="formStoreName" form-namespace="single.title"
                />
                <pf-form-input :column-label="$t('Firstname')"
                  :form-store-name="formStoreName" form-namespace="single.firstname"
                />
                <pf-form-input :column-label="$t('Lastname')"
                  :form-store-name="formStoreName" form-namespace="single.lastname"
                />
                <pf-form-input :column-label="$t('Nickname')"
                  :form-store-name="formStoreName" form-namespace="single.nickname"
                />
                <pf-form-input :column-label="$t('Company')"
                  :form-store-name="formStoreName" form-namespace="single.company"
                />
                <pf-form-input :column-label="$t('Telephone number')"
                  :form-store-name="formStoreName" form-namespace="single.telephone"
                />
                <pf-form-input :column-label="$t('Cellphone number')"
                  :form-store-name="formStoreName" form-namespace="single.cell_phone"
                />
                <pf-form-input :column-label="$t('Workphone number')"
                  :form-store-name="formStoreName" form-namespace="single.work_phone"
                />
                <pf-form-input :column-label="$t('Apartment number')"
                  :form-store-name="formStoreName" form-namespace="single.apartment_number"
                />
                <pf-form-input :column-label="$t('Building Number')"
                  :form-store-name="formStoreName" form-namespace="single.building_number"
                />
                <pf-form-input :column-label="$t('Room Number')"
                  :form-store-name="formStoreName" form-namespace="single.room_number"
                />
                <pf-form-textarea :column-label="$t('Address')"
                  :form-store-name="formStoreName" form-namespace="single.address"
                  rows="4" max-rows="6"
                />
                <pf-form-datetime :column-label="$t('Anniversary')"
                  :form-store-name="formStoreName" form-namespace="single.anniversary"
                  :config="{datetimeFormat: schema.person.anniversary.format}"
                />
                <pf-form-datetime :column-label="$t('Birthday')"
                  :form-store-name="formStoreName" form-namespace="single.birthday"
                  :config="{datetimeFormat: schema.person.birthday.format}"
                />
                <pf-form-input :column-label="$t('Psk')"
                  :form-store-name="formStoreName" form-namespace="single.psk"
                />
                <pf-form-textarea :column-label="$t('Notes')"
                  :form-store-name="formStoreName" form-namespace="single.notes"
                  rows="3" max-rows="3"
                />
                <pf-form-input :column-label="$t('Custom Field 1')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_1"
                />
                <pf-form-input :column-label="$t('Custom Field 2')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_2"
                />
                <pf-form-input :column-label="$t('Custom Field 3')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_3"
                />
                <pf-form-input :column-label="$t('Custom Field 4')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_4"
                />
                <pf-form-input :column-label="$t('Custom Field 5')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_5"
                />
                <pf-form-input :column-label="$t('Custom Field 6')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_6"
                />
                <pf-form-input :column-label="$t('Custom Field 7')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_7"
                />
                <pf-form-input :column-label="$t('Custom Field 8')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_8"
                />
                <pf-form-input :column-label="$t('Custom Field 9')"
                  :form-store-name="formStoreName" form-namespace="single.custom_field_9"
                />
              </b-col>
            </b-form-row>
          </b-form>
        </b-tab>
        <template v-can:create-multiple="'users'">
          <b-tab :title="$t('Multiple')">
            <pf-form-row>
              <b-alert show variant="info" v-html="$t('The usernames are constructed from the <b>prefix</b> and the <b>quantity</b>. For example, setting the prefix to <i>guest</i> and the quantity to <i>3</i> creates usernames <i>guest1</i>, <i>guest2</i> and <i>guest3</i>. Random passwords will be created.')"></b-alert>
            </pf-form-row>
            <b-form @submit.prevent="create()">
              <b-form-row align-v="center">
                <b-col sm="12">
                  <pf-form-range-toggle :column-label="$t('Username (PID) overwrite')"
                    :form-store-name="formStoreName" form-namespace="multiple.pid_overwrite"
                    :values="{checked: 1, unchecked: 0}"
                    :rightLabels="{checked: $t('Overwrite'), unchecked: $t('Ignore')}"
                    :text="$t('Overwrite the username (PID) if it already exists.')"
                  />
                  <pf-form-input :column-label="$t('Username Prefix')"
                    :form-store-name="formStoreName" form-namespace="multiple.prefix"
                  />
                  <pf-form-input :column-label="$t('Username Suffix')"
                    v-model="domainName" disabled
                  />
                  <pf-form-input :column-label="$t('Quantity')"
                    :form-store-name="formStoreName" form-namespace="multiple.quantity"
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
                    :form-store-name="formStoreName" form-namespace="multiple.login_remaining"
                    type="number"
                    :text="$t('Leave empty to allow unlimited logins.')"
                  />
                  <pf-form-input :column-label="$t('Firstname')"
                    :form-store-name="formStoreName" form-namespace="multiple.firstname"
                  />
                  <pf-form-input :column-label="$t('Lastname')"
                    :form-store-name="formStoreName" form-namespace="multiple.lastname"
                  />
                  <pf-form-input :column-label="$t('Company')"
                    :form-store-name="formStoreName" form-namespace="multiple.company"
                  />
                  <pf-form-textarea :column-label="$t('Notes')"
                    :form-store-name="formStoreName" form-namespace="multiple.notes"
                    rows="3" max-rows="3"
                  />
                </b-col>
              </b-form-row>
            </b-form>
          </b-tab>
        </template>
      </b-tabs>

      <b-container class="card-body" fluid>
        <b-form-row>
          <b-col sm="12">

            <b-form-group label-cols="3" :label="$t('Registration Window')">
              <b-row>
                <b-col>
                  <pf-form-input
                    :form-store-name="formStoreName" form-namespace="common.valid_from"
                  />
                </b-col>
                <p class="pt-2"><icon name="long-arrow-alt-right"></icon></p>
                <b-col>
                  <pf-form-input
                    :form-store-name="formStoreName" form-namespace="common.expiration"
                  />
                </b-col>
              </b-row>
            </b-form-group>
            <pf-form-fields :column-label="$t('Actions')"
              :form-store-name="formStoreName" form-namespace="common.actions"
              :button-label="$t('Add Action')"
              :field="actionField"
              :invalid-feedback="$t('Action(s) contain one or more errors.')"
              sortable
            ></pf-form-fields>
          </b-col>
          <b-col sm="4"></b-col>
        </b-form-row>
      </b-container>

      <b-card-footer>
        <b-button variant="primary" :disabled="invalidForm" @click="create()">
          <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Create') }}
        </b-button>
      </b-card-footer>

    </b-card>

    <users-preview-modal v-model="showUsersPreviewModal" store-name="$_users"/>

  </div>
</template>

<script>
/* eslint-disable no-unused-vars */
import {
  BaseInput,
  BaseFormGroup
} from '@/components/new/'


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
import { pfActions } from '@/globals/pfActions'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import {
  pfFieldType,
  pfFieldTypeValues
} from '@/globals/pfField'
import {
  createForm, createValidators,
  passwordOptions
} from '../_config/'

/* eslint-disable vue/no-unused-components */
export default {
  name: 'users-create',
  components: {
    BaseInput,
    BaseFormGroup,

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
      schema, // @/globals/pfDatabaseSchema
      actionField: {
        component: pfFieldTypeValue,
        attrs: {
          typeLabel: this.$i18n.t('Select action type'),
          valueLabel: this.$i18n.t('Select action value'),
          fields: []
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
    domainName () {
      const { domain_name = null } = this.$store.getters['session/tenantMask'] || {}
      return domain_name
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
    test () {
      return new Promise(resolve => {
        setTimeout(() => {
          resolve(new Error('GTFO'))
        }, 3000)
      })
    },


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
          let data = {
            ...this.form.single,
            ...this.form.common
          }
          if (this.domainName) { // append domainName to pid when available (tenant)
            data.pid = `${data.pid}@${this.domainName}`
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
            let pid = this.form.multiple.prefix + (i + 1)
            if (this.domainName) { // append domainName to pid when available (tenant)
              pid = `${pid}@${this.domainName}`
            }
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
  created () {
    this.$store.dispatch('session/getAllowedUserActions').then(actions => {
      this.actionField.attrs.fields = actions.map(({action}) => {
        switch (action) {
          case 'set_access_duration':
          case 'set_access_level':
          case 'set_role':
          case 'set_unreg_date':
            return pfActions[`${action}_by_acl_user`] // remap action to user ACL
            // break
          default:
            return pfActions[action]
        }
      })
    })
    this.$store.dispatch('config/getAdminRoles')
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getTenants')
    this.$store.dispatch('config/getBaseGuestsAdminRegistration') // for access durations
  },
  mounted () {
    this.init()
  }
}
</script>
