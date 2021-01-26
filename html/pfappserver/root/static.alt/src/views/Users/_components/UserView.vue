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
            :form-store-name="formStoreName" form-namespace="pid"
            :text="$t('The username used for login to the captive portal.')"
            readonly
          />
          <pf-form-input :column-label="$t('Email')"
            :form-store-name="formStoreName" form-namespace="email"
          />
          <pf-form-input :column-label="$t('Sponsor')"
            :form-store-name="formStoreName" form-namespace="sponsor"
          />
          <pf-form-input :column-label="$t('Language')"
            :form-store-name="formStoreName" form-namespace="lang"
          />
          <pf-form-chosen :column-label="$t('Gender')"
            :form-store-name="formStoreName" form-namespace="gender"
            label="text"
            track-by="value"
            :placeholder="$t('Choose gender')"
            :options="genders"
          />
          <pf-form-input :column-label="$t('Title')"
            :form-store-name="formStoreName" form-namespace="title"
          />
          <pf-form-input :column-label="$t('Firstname')"
            :form-store-name="formStoreName" form-namespace="firstname"
          />
          <pf-form-input :column-label="$t('Lastname')"
            :form-store-name="formStoreName" form-namespace="lastname"
          />
          <pf-form-input :column-label="$t('Nickname')"
            :form-store-name="formStoreName" form-namespace="nickname"
          />
          <pf-form-input :column-label="$t('Company')"
            :form-store-name="formStoreName" form-namespace="company"
          />
          <pf-form-input :column-label="$t('Telephone number')"
            :form-store-name="formStoreName" form-namespace="telephone"
          />
          <pf-form-input :column-label="$t('Cellphone number')"
            :form-store-name="formStoreName" form-namespace="cell_phone"
          />
          <pf-form-input :column-label="$t('Workphone number')"
            :form-store-name="formStoreName" form-namespace="work_phone"
          />
          <pf-form-input :column-label="$t('Apartment number')"
            :form-store-name="formStoreName" form-namespace="apartment_number"
          />
          <pf-form-input :column-label="$t('Building Number')"
            :form-store-name="formStoreName" form-namespace="building_number"
          />
          <pf-form-input :column-label="$t('Room Number')"
            :form-store-name="formStoreName" form-namespace="room_number"
          />
          <pf-form-textarea :column-label="$t('Address')"
            :form-store-name="formStoreName" form-namespace="address"
             rows="4" max-rows="6"
          />
          <pf-form-datetime :column-label="$t('Anniversary')"
            :form-store-name="formStoreName" form-namespace="anniversary"
            :config="{datetimeFormat: schema.person.anniversary.format}"
          />
          <pf-form-datetime :column-label="$t('Birthday')"
            :form-store-name="formStoreName" form-namespace="birthday"
            :config="{datetimeFormat: schema.person.birthday.format}"
          />
          <pf-form-input :column-label="$t('Psk')"
            :form-store-name="formStoreName" form-namespace="psk"
          />
          <pf-form-textarea :column-label="$t('Notes')"
            :form-store-name="formStoreName" form-namespace="notes"
            rows="3" max-rows="3"
          />
        </b-tab>

        <b-tab title="Password" v-if="!!form.expiration">
          <template v-slot:title>
            {{ $t('Password') }}
          </template>
          <pf-form-password :column-label="$t('Password')"
            :form-store-name="formStoreName" form-namespace="password"
            :text="$t('Leave empty to keep current password.')"
            generate
          />
          <pf-form-input :column-label="$t('Login remaining')"
            :form-store-name="formStoreName" form-namespace="login_remaining"
            :text="$t('Leave empty to allow unlimited logins.')"
            type="number"
          />
        </b-tab>

        <b-tab title="Actions">
          <b-form-group label-cols="3" :label="$t('Registration Window')">
            <b-row>
              <b-col>
                <pf-form-input
                  :form-store-name="formStoreName" form-namespace="valid_from"
                />
              </b-col>
              <p class="pt-2"><icon name="long-arrow-alt-right"></icon></p>
              <b-col>
                <pf-form-input
                  :form-store-name="formStoreName" form-namespace="expiration"
                />
              </b-col>
            </b-row>
          </b-form-group>

          <pf-form-fields :column-label="$t('Actions')"
            :form-store-name="formStoreName" form-namespace="actions"
            :button-label="$t('Add Action')"
            :field="actionField"
            :invalid-feedback="$t('Action(s) contain one or more errors.')"
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
                :form-store-name="formStoreName" :form-namespace="`custom_field_${i}`"
              />
            </b-col>
          </b-form-row>
        </b-tab>

        <b-tab title="Devices">
          <template v-slot:title>
            {{ $t('Devices') }} <b-badge pill v-if="hasNodes" variant="light" class="ml-1">{{ nodes.length }}</b-badge>
          </template>
          <b-row align-h="between" align-v="center">
            <b-col cols="auto" class="mr-auto">
              <b-dropdown size="sm" class="mb-2" variant="link" :disabled="isLoadingNodes || !hasNodes" no-caret>
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

          <b-table :items="nodes" :fields="visibleNodeFields" :sortBy="nodeSortBy" :sortDesc="nodeSortDesc" show-empty responsive sort-icon-left striped>
            <template v-slot:cell(status)="node">
              <b-badge pill variant="success" v-if="node.item.status === 'reg'">{{ $t('registered') }}</b-badge>
              <b-badge pill variant="secondary" v-else-if="node.item.status === 'unreg'">{{ $t('unregistered') }}</b-badge>
              <span v-else>{{ node.item.status }}</span>
            </template>
            <template v-slot:cell(mac)="node">
              <b-button variant="link" :to="`../../node/${node.item.mac}`">{{ node.item.mac }}</b-button>
            </template>
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoadingNodes" text="">{{ $t('No devices found') }}</pf-empty-table>
            </template>
            <template v-slot:table-caption v-if="nodes.length >= 1000" class="text-center">
              <b-button variant="outline-primary mb-0" :to="{ name: 'nodeSearch', query: {
                query: JSON.stringify({
                  'op':'and',
                  'values':[
                    {
                      op:'or',
                      values:[
                        { field: 'pid', op: 'equals', value: pid }
                      ]
                    }
                  ]
                })
              } }">{{ $t('View All') }}</b-button>
            </template>
          </b-table>
        </b-tab>

        <b-tab title="Security Events">
          <template v-slot:title>
            {{ $t('Security Events') }} <b-badge pill v-if="securityEvents && securityEvents.length > 0" variant="light" class="ml-1">{{ securityEvents.length }}</b-badge>
          </template>
          <b-table :items="securityEvents" :fields="securityEventFields" :sortBy="securityEventSortBy" :sortDesc="securityEventSortDesc" show-empty responsive sort-icon-left striped>
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
                <b-button size="sm" v-if="securityEvent.item.status === 'open'" variant="outline-danger" :disabled="isLoadingSecurityEvents" @click="closeSecurityEvent(securityEvent)">{{ $t('Close Event') }}</b-button>
              </span>
            </template>
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoadingSecurityEvents" text="">{{ $t('No security events found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>
      </b-tabs>
      <b-card-footer>
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
  userActions,
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
      actionField: {
        component: pfFieldTypeValue,
        attrs: {
          typeLabel: this.$i18n.t('Select action type'),
          valueLabel: this.$i18n.t('Select action value'),
          fields: userActions // ../_config/
        }
      },
      genders: pfFieldTypeValues[pfFieldType.GENDER](),
      nodes: [],
      nodeFields, // ../_config/
      nodeSortBy: 'status',
      nodeSortDesc: false,
      securityEvents: [],
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
    isLoading () {
      return this.$store.getters['$_users/isLoading']
    },
    isLoadingNodes () {
      return this.$store.getters['$_users/isLoadingNodes']
    },
    isLoadingSecurityEvents () {
      return this.$store.getters['$_users/isLoadingSecurityEvents']
    },
    disableSave () {
      return this.invalidForm || this.isLoading
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    },
    isDefaultUser () {
      const { form: { pid } = {} } = this
      return pid === 'default'
    },
    visibleNodeFields () {
      return this.nodeFields.filter(field => field.visible || field.locked)
    },
    hasNodes () {
      return (Array.isArray(this.nodes) && this.nodes.length > 0)
    },
    hasOpenSecurityEvents () {
      return (Array.isArray(this.securityEvents) && this.securityEvents.findIndex(securityEvent => securityEvent.status === 'open') > -1)
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_users/getUserNodes', this.pid).then(nodes => {
        this.nodes = nodes
      })
      this.$store.dispatch('$_users/getUserSecurityEvents', this.pid).then(securityEvents => {
        this.securityEvents = securityEvents
      })
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
        if (this.form.expiration) { // has password
          this.$store.dispatch('$_users/updatePassword', Object.assign({ quiet: true }, this.form))
        }
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    deleteUser () {
      this.$store.dispatch('$_users/deleteUser', this.pid).then(() => {
        this.$router.push('/users/search')
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
      this.$store.dispatch('$_users/unassignUserNodes', this.pid)
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
