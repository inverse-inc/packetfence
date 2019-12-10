<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <pf-button-refresh class="border-right pr-3" :isLoading="isLoading" @refresh="refresh"></pf-button-refresh>
        <h4 class="mb-0" v-html="$t('User {pid}', { pid: $strong(pid) })"></h4>
      </b-card-header>
      <b-tabs ref="tabs" v-model="tabIndex" card>

        <b-tab title="Profile" active>
          <template v-slot:title>
            {{ $t('Profile') }}
          </template>
          <pf-form-input :column-label="$t('Username (PID)')"
            :formStoreName="formStoreName" formNamespace="pid"
            :text="$t('The username used for login to the captive portal.')"
            readonly
          />
          <pf-form-input :column-label="$t('Email')"
            :formStoreName="formStoreName" formNamespace="email"
          />
          <pf-form-input :column-label="$t('Sponsor')"
            :formStoreName="formStoreName" formNamespace="sponsor"
          />
          <pf-form-input :column-label="$t('Language')"
            :formStoreName="formStoreName" formNamespace="lang"
          />
          <pf-form-chosen :column-label="$t('Gender')"
            :formStoreName="formStoreName" formNamespace="gender"
            label="text"
            track-by="value"
            :placeholder="$t('Choose gender')"
            :options="genders"
          />
          <pf-form-input :column-label="$t('Title')"
            :formStoreName="formStoreName" formNamespace="title"
          />
          <pf-form-input :column-label="$t('Firstname')"
            :formStoreName="formStoreName" formNamespace="firstname"
          />
          <pf-form-input :column-label="$t('Lastname')"
            :formStoreName="formStoreName" formNamespace="lastname"
          />
          <pf-form-input :column-label="$t('Nickname')"
            :formStoreName="formStoreName" formNamespace="nickname"
          />
          <pf-form-input :column-label="$t('Company')"
            :formStoreName="formStoreName" formNamespace="company"
          />
          <pf-form-input :column-label="$t('Telephone number')"
            :formStoreName="formStoreName" formNamespace="telephone"
          />
          <pf-form-input :column-label="$t('Cellphone number')"
            :formStoreName="formStoreName" formNamespace="cell_phone"
          />
          <pf-form-input :column-label="$t('Workphone number')"
            :formStoreName="formStoreName" formNamespace="work_phone"
          />
          <pf-form-input :column-label="$t('Apartment number')"
            :formStoreName="formStoreName" formNamespace="apartment_number"
          />
          <pf-form-input :column-label="$t('Building Number')"
            :formStoreName="formStoreName" formNamespace="building_number"
          />
          <pf-form-input :column-label="$t('Room Number')"
            :formStoreName="formStoreName" formNamespace="room_number"
          />
          <pf-form-textarea :column-label="$t('Address')"
            :formStoreName="formStoreName" formNamespace="address"
             rows="4" max-rows="6"
          />
          <pf-form-datetime :column-label="$t('Anniversary')"
            :formStoreName="formStoreName" formNamespace="anniversary"
            :config="{datetimeFormat: schema.person.anniversary.format}"
          />
          <pf-form-datetime :column-label="$t('Birthday')"
            :formStoreName="formStoreName" formNamespace="birthday"
            :config="{datetimeFormat: schema.person.birthday.format}"
          />
          <pf-form-input :column-label="$t('Psk')"
            :formStoreName="formStoreName" formNamespace="psk"
          />
          <pf-form-textarea :column-label="$t('Notes')"
            :formStoreName="formStoreName" formNamespace="notes"
            rows="3" max-rows="3"
          />
        </b-tab>

        <b-tab title="Password" v-if="!!form.expiration">
          <template v-slot:title>
            {{ $t('Password') }}
          </template>
          <pf-form-password :column-label="$t('Password')"
            :formStoreName="formStoreName" formNamespace="password"
            :text="$t('Leave empty to keep current password.')"
            generate
          />
          <pf-form-input :column-label="$t('Login remaining')"
            :formStoreName="formStoreName" formNamespace="login_remaining"
            :text="$t('Leave empty to allow unlimited logins.')"
            type="number"
          />
        </b-tab>

        <b-tab title="Actions" v-if="!!form.expiration">

          <b-form-group label-cols="3" :label="$t('Registration Window')">
            <b-row>
              <b-col>
                <pf-form-datetime
                  :formStoreName="formStoreName" formNamespace="valid_from"
                  :config="{datetimeFormat: schema.password.valid_from.datetimeFormat}"
                />
              </b-col>
              <p class="pt-2"><icon name="long-arrow-alt-right"></icon></p>
              <b-col>
                <pf-form-datetime
                  :formStoreName="formStoreName" formNamespace="expiration"
                  :config="{datetimeFormat: schema.password.expiration.datetimeFormat}"
                />
              </b-col>
            </b-row>
          </b-form-group>

          <pf-form-fields :column-label="$t('Actions')"
            :formStoreName="formStoreName" formNamespace="actions"
            :button-label="$t('Add Action')"
            :field="actionField"
            sortable
          />
        </b-tab>

        <b-tab title="Custom Fields">
          <template v-slot:title>
            {{ $t('Custom Fields') }}
          </template>
          <b-form-row>
            <b-col>
              <pf-form-input v-for="i in 9"  :column-label="'Custom Field ' + i" :key="i"
                :formStoreName="formStoreName" :formNamespace="`custom_field_${i}`"
              />
            </b-col>
          </b-form-row>
        </b-tab>

        <b-tab title="Devices">
          <template v-slot:title>
            {{ $t('Devices') }} <b-badge pill v-if="hasNodes" variant="light" class="ml-1">{{ form.nodes.length }}</b-badge>
          </template>
          <b-row align-h="between" align-v="center">
            <b-col cols="auto" class="mr-auto">
              <b-dropdown size="sm" class="mb-2" variant="link" :disabled="isLoading || !hasNodes" no-caret>
                <template v-slot:button-content>
                  <icon name="columns" v-b-tooltip.hover.top.d300.window :title="$t('Visible Columns')"></icon>
                </template>
                <template v-for="column in nodeFields">
                  <b-dropdown-item :key="column.key" v-if="column.locked" disabled>
                    <icon class="position-absolute mt-1" name="thumbtack"></icon>
                    <span class="ml-4">{{column.label}}</span>
                  </b-dropdown-item>
                  <a :key="column.key" v-else href="javascript:void(0)" :disabled="column.locked" class="dropdown-item" @click.stop="toggleDeviceColumn(column)">
                    <icon class="position-absolute mt-1" name="check" v-show="column.visible"></icon>
                    <span class="ml-4">{{column.label}}</span>
                  </a>
                </template>
              </b-dropdown>
            </b-col>
          </b-row>

          <b-table :items="form.nodes" :fields="visibleNodeFields" :sortBy="nodeSortBy" :sortDesc="nodeSortDesc" show-empty responsive striped>
            <template v-slot:cell(status)="node">
              <b-badge pill variant="success" v-if="node.item.status === 'reg'">{{ $t('registered') }}</b-badge>
              <b-badge pill variant="secondary" v-else-if="node.item.status === 'unreg'">{{ $t('unregistered') }}</b-badge>
              <span v-else>{{ node.item.status }}</span>
            </template>
            <template v-slot:cell(mac)="node">
              <b-button variant="link" :to="`../../node/${node.item.mac}`">{{ node.item.mac }}</b-button>
            </template>
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoading" text="">{{ $t('No devices found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>

        <b-tab title="Security Events">
          <template v-slot:title>
            {{ $t('Security Events') }} <b-badge pill v-if="form.security_events && form.security_events.length > 0" variant="light" class="ml-1">{{ form.security_events.length }}</b-badge>
          </template>
          <b-table :items="form.security_events" :fields="securityEventFields" :sortBy="securityEventSortBy" :sortDesc="securityEventSortDesc" show-empty responsive striped>
            <template v-slot:cell(status)="securityEvent">
              <b-badge pill variant="success" v-if="securityEvent.item.status === 'open'">{{ $t('open') }}</b-badge>
              <b-badge pill variant="secondary" v-else-if="securityEvent.item.status === 'closed'">{{ $t('closed') }}</b-badge>
              <span v-else>{{ securityEvent.item.status }}</span>
            </template>
            <template v-slot:cell(mac)="securityEvent">
              <b-button variant="link" :to="`../../node/${securityEvent.item.mac}`"><mac>{{ securityEvent.item.mac }}</mac></b-button>
            </template>
            <template v-slot:cell(buttons)="securityEvent">
              <span class="float-right text-nowrap">
                <b-button size="sm" v-if="securityEvent.item.status === 'open'" variant="outline-danger" :disabled="isLoading" @click="closeSecurityEvent(securityEvent)">{{ $t('Close Event') }}</b-button>
              </span>
            </template>
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoading" text="">{{ $t('No security events found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>
      </b-tabs>
      <b-card-footer @mouseenter="$v.$touch()">
        <pf-button-save class="mr-1" v-if="ifTab(['Profile', 'Actions', 'Custom Fields'])" :disabled="disableSave" :isLoading="isLoading">
          <template v-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete class="mr-3" v-if="ifTab(['Profile', 'Custom Fields']) && !isDefaultUser" :disabled="isLoading" :confirm="$t('Delete User?')" @on-delete="deleteUser()"/>
        <b-button class="mr-1" v-if="ifTab(['Password'])" variant="outline-primary" :disabled="isLoading" @click="resetPassword()">{{ $t('Reset Password') }}</b-button>
        <b-button class="mr-1" v-if="ifTab(['Devices']) && !isDefaultUser" variant="outline-primary" :disabled="isLoading || !hasNodes" @click="unassignNodes()">{{ $t('Unassign Nodes') }}</b-button>
        <b-button class="mr-1" v-if="ifTab(['Security Events'])" variant="outline-primary" :disabled="isLoading || !hasOpenSecurityEvents" @click="closeSecurityEvents()">{{ $t('Close all security events') }}</b-button>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
/* eslint-disable camelcase */
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonRefresh from '@/components/pfButtonRefresh'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  actions,
  nodeFields,
  securityEventFields,
  updateValidators
} from '../_config/'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import {
  pfFieldType,
  pfFieldTypeValues
} from '@/globals/pfField'

export default {
  name: 'user-view',
  components: {
    pfButtonSave,
    pfButtonDelete,
    pfButtonRefresh,
    pfEmptyTable,
    pfFormChosen,
    pfFormDatetime,
    pfFormFields,
    pfFormInput,
    pfFormPassword,
    pfFormTextarea
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    },
    pid: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      schema, // @/globals/pfDatabaseSchema
      tabIndex: 0,
      tabTitle: '',
      userContent: { nodes: [], security_events: [] },
      actionField: {
        component: pfFieldTypeValue,
        attrs: {
          typeLabel: this.$i18n.t('Select action type'),
          valueLabel: this.$i18n.t('Select action value'),
          fields: actions // ../_config/
        }
      },
      genders: pfFieldTypeValues[pfFieldType.GENDER](),
      nodeFields, // ../_config/
      nodeSortBy: 'status',
      nodeSortDesc: false,
      securityEventFields, // ../_config/
      securityEventSortBy: 'start_date',
      securityEventSortDesc: true
    }
  },
  computed: {
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    node () {
      return this.$store.state.$_users.users[this.pid]
    },
    isLoading () {
      return this.$store.getters['$_users/isLoading']
    },
    hasNodes () {
      const { form: { nodes = [] } = {} } = this
      return (Array.isArray(nodes) && nodes.length > 0)
    },
    hasOpenSecurityEvents () {
      const { form: { security_events = [] } = {} } = this
      return (Array.isArray(security_events) && security_events.findIndex(securityEvent => securityEvent.status === 'open') > -1)
    },
    isDefaultUser () {
      const { form: { pid } = {} } = this
      return pid === 'default'
    },
    visibleNodeFields () {
      return this.nodeFields.filter(field => field.visible || field.locked)
    },
    disableSave () {
      return this.invalidForm || this.isLoading
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.formStoreName}/clearForm`)
      this.$store.dispatch(`${this.formStoreName}/clearFormValidations`)
      this.$store.dispatch('$_users/getUser', this.pid).then(user => {
        // setup form store module
        this.$store.dispatch(`${this.formStoreName}/setForm`, user)
        this.$store.dispatch(`${this.formStoreName}/setFormValidations`, updateValidators)
      })
    },
    close () {
      this.$router.back()
    },
    refresh () {
      this.$store.dispatch('$_users/refreshUser', this.pid).then(user => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, user)
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_users/updateUser', this.form).then(() => {
        if (!!this.form.expiration) { // has password
          this.$store.dispatch('$_users/updatePassword', Object.assign({ quiet: true }, this.form))
        }
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    deleteUser () {
      this.$store.dispatch('$_users/deleteUser', this.pid).then(() => {
        this.close()
      })
    },
    closeSecurityEvent (securityEvent) {
      // TODO
      // eslint-disable-next-line
      console.log('closeSecurityEvent', securityEvent)
    },
    closeSecurityEvents () {
      // TODO
      // eslint-disable-next-line
      console.log('closeSecurityEvents')
    },
    unassignNodes () {
      this.$store.dispatch('$_users/unassignUserNodes', this.pid).then(() => {
        this.form.nodes = []
      })
    },
    resetPassword () {
      const data = {
        pid: this.pid,
        tenant_id: this.tenant_id,
        password: this.form.password,
        login_remaining: this.form.login_remaining
      }
      this.$store.dispatch('$_users/updatePassword', data)
    },
    toggleDeviceColumn (column) {
      const index = this.nodeFields.findIndex(field => field.key === column.key)
      this.$set(this.nodeFields[index], 'visible', !this.nodeFields[index].visible)
    },
    ifTab (set) {
      return this.$refs.tabs &&
        this.$refs.tabs.tabs[this.tabIndex] &&
        set.includes(this.$refs.tabs.tabs[this.tabIndex].title)
    }
  },
  mounted () {
    this.$store.dispatch('config/getAdminRoles')
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getTenants')
    this.$store.dispatch('config/getBaseGuestsAdminRegistration') // for access durations
    this.init()
  },
  watch: {
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
