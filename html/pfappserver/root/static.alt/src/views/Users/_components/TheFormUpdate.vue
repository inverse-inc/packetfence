<template>
  <b-form @submit.prevent ref="rootRef">
    <base-form
      :form="form"
      :schema="schema"
      :isLoading="isLoading"
      class="pt-0"
    >    
      <b-tabs v-model="tabIndex" card>

        <base-form-tab :title="$i18n.t('Profile')">
          <form-group-pid namespace="pid"
            :column-label="$i18n.t('Username (PID)')"
            :text="$t('The username to use for login to the captive portal.')"
          />
          
          <form-group-email namespace="email"
            :column-label="$t('Email')" />

          <form-group-sponsor namespace="sponsor"
            :column-label="$t('Sponsor')" />

          <form-group-language namespace="lang"
            :column-label="$t('Language')" />

          <form-group-gender namespace="gender"
            :column-label="$t('Gender')" />
          
          <form-group-title namespace="title"
            :column-label="$t('Title')" />

          <form-group-firstname namespace="firstname"
            :column-label="$t('Firstname')" />

          <form-group-lastname namespace="lastname"
            :column-label="$t('Lastname')" />

          <form-group-nickname namespace="nickname"
            :column-label="$t('Nickname')" />

          <form-group-company namespace="company"
            :column-label="$t('Company')" />

          <form-group-telephone namespace="telephone"
            :column-label="$t('Telephone number')" />

          <form-group-cell-phone namespace="cell_phone"
            :column-label="$t('Cellphone number')" />

          <form-group-work-phone namespace="work_phone"
            :column-label="$t('Workphone number')" />

          <form-group-apartment-number namespace="apartment_number"
            :column-label="$t('Apartment number')" />

          <form-group-building-number namespace="building_number"
            :column-label="$t('Building Number')" />

          <form-group-room-number namespace="room_number"
            :column-label="$t('Room Number')" />

          <form-group-address namespace="address"
            :column-label="$t('Address')" />

          <form-group-anniversary namespace="anniversary"
            :column-label="$t('Anniversary')" />

          <form-group-birthday namespace="birthday"
            :column-label="$t('Birthday')" />

          <form-group-psk namespace="psk"
            :column-label="$t('Psk')" />

          <form-group-notes namespace="notes"
            :column-label="$t('Notes')" />
            
          <div class="mt-3">
            <div class="border-top pt-3">
              <base-form-button-bar
                :isDeletable="!isDefaultUser"
                :isLoading="isLoading"
                isSaveable
                :isValid="isValid"
                :formRef="rootRef"
                @close="onClose"
                @reset="onReset"
                @remove="onRemove"
                @save="onSave"
              />
            </div>
          </div>
        </base-form-tab>
        
        <base-form-tab :title="$i18n.t('Actions')">
          <base-form-group
            :column-label="$t('Registration Window')">
            <input-group-valid-from namespace="valid_from"
              class="flex-grow-1" />
            <b-button variant="link" disabled><icon name="long-arrow-alt-right"></icon></b-button>
            <input-group-expiration namespace="expiration"
              class="flex-grow-1" />
          </base-form-group>
          
          <form-group-actions namespace="actions"
            :column-label="$t('Actions')" />

          <div class="mt-3">
            <div class="border-top pt-3">
              <base-form-button-bar
                :isDeletable="!isDefaultUser"
                :isLoading="isLoading"
                isSaveable
                :isValid="isValid"
                :formRef="rootRef"
                @close="onClose"
                @remove="onRemove"
                @reset="onReset"
                @save="onSave"
              />
            </div>
          </div>
        </base-form-tab>
        
        <base-form-tab :title="$i18n.t('Custom Fields')">
          <form-group-custom-field-1 namespace="custom_field_1"
            :column-label="$t('Custom Field 1')" />

          <form-group-custom-field-2 namespace="custom_field_2"
            :column-label="$t('Custom Field 2')" />

          <form-group-custom-field-3 namespace="custom_field_3"
            :column-label="$t('Custom Field 3')" />

          <form-group-custom-field-4 namespace="custom_field_4"
            :column-label="$t('Custom Field 4')"  />

          <form-group-custom-field-5 namespace="custom_field_5"
            :column-label="$t('Custom Field 5')" />

          <form-group-custom-field-6 namespace="custom_field_6"
            :column-label="$t('Custom Field 6')" />

          <form-group-custom-field-7 namespace="custom_field_7"
            :column-label="$t('Custom Field 7')" />

          <form-group-custom-field-8 namespace="custom_field_8"
            :column-label="$t('Custom Field 8')" />

          <form-group-custom-field-9 namespace="custom_field_9"
            :column-label="$t('Custom Field 9')" />          

          <div class="mt-3">
            <div class="border-top pt-3">
              <base-form-button-bar
                :isDeletable="!isDefaultUser"
                :isLoading="isLoading"
                isSaveable
                :isValid="isValid"
                :formRef="rootRef"
                @close="onClose"
                @remove="onRemove"
                @reset="onReset"
                @save="onSave"
              />
            </div>
          </div>
        </base-form-tab>      
        
        <base-form-tab :title="$i18n.t('Password')" v-if="isExpiration">
          <form-group-password namespace="password"
            :column-label="$t('Password')"
            :text="$t('Leave empty to keep current password.')"
          />

          <form-group-login-remaining namespace="login_remaining"
            :column-label="$t('Login remaining')"
            :text="$t('Leave empty to allow unlimited logins.')"
          />
          
          <div class="mt-3">
            <div class="border-top pt-3">
             <b-button class="mr-1" variant="outline-primary" :disabled="isLoading" @click="onResetPassword">{{ $t('Reset Password') }}</b-button>
            </div>
          </div>          
        </base-form-tab>        

        <b-tab title="Devices">
          <template v-slot:title>
            {{ $t('Devices') }} <b-badge pill v-if="hasNodes" variant="light" class="ml-1">{{ nodes.length }}</b-badge>
          </template>
          
          <b-row align-h="between" align-v="center">
            <b-col cols="auto" class="mr-auto">
              <b-dropdown size="sm" class="mb-2" variant="link" :disabled="isLoadingNodes" no-caret>
                <template v-slot:button-content>
                  <icon name="columns" v-b-tooltip.hover.top.d300.window :title="$t('Visible Columns')"></icon>
                </template>
                <template v-for="column in nodeFields">
                  <b-dropdown-item v-if="column.locked"
                    :key="column.key" disabled>
                    <icon class="position-absolute mt-1" name="thumbtack"></icon>
                    <span class="ml-4">{{column.label}}</span>
                  </b-dropdown-item>
                  <a v-else
                   :key="column.key" href="javascript:void(0)" :disabled="column.locked" class="dropdown-item" @click.stop="onNodeFieldToggle(column)">
                    <icon class="position-absolute mt-1" name="check" v-show="column.visible"></icon>
                    <span class="ml-4">{{column.label}}</span>
                  </a>
                </template>
              </b-dropdown>
            </b-col>
          </b-row>

          <b-table :items="nodes" :fields="visibleNodeFields" :sortBy="nodeSortBy" :sortDesc="nodeSortDesc" 
            class="pb-3" show-empty responsive sort-icon-left striped>
            <template v-slot:cell(status)="node">
              <b-badge pill variant="success" v-if="node.item.status === 'reg'">{{ $t('registered') }}</b-badge>
              <b-badge pill variant="secondary" v-else-if="node.item.status === 'unreg'">{{ $t('unregistered') }}</b-badge>
              <span v-else>{{ node.item.status }}</span>
            </template>
            <template v-slot:cell(mac)="node">
              <b-button variant="link" :to="`../../node/${node.item.mac}`">{{ node.item.mac }}</b-button>
            </template>
            <template v-slot:empty>
              <base-table-empty :isLoading="isLoadingNodes" text="">{{ $t('No devices found') }}</base-table-empty>
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
          
          <div class="mt-3">
            <div class="border-top pt-3">
             <b-button class="mr-1" v-if="!isDefaultUser" variant="outline-primary" :disabled="isLoadingNodes || !hasNodes" @click="onNodesUnassign">{{ $t('Unassign Nodes') }}</b-button>
            </div> 
          </div> 
        </b-tab>
      
        <b-tab title="Security Events">
          <template v-slot:title>
            {{ $t('Security Events') }} <b-badge pill v-if="securityEvents && securityEvents.length > 0" variant="light" class="ml-1">{{ securityEvents.length }}</b-badge>
          </template>      
          
          <b-table :items="securityEvents" :fields="securityEventFields" :sortBy="securityEventSortBy" :sortDesc="securityEventSortDesc" 
            class="pb-3" show-empty responsive sort-icon-left striped>
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
                <b-button size="sm" v-if="securityEvent.item.status === 'open'" variant="outline-danger" :disabled="isLoadingSecurityEvents" @click="onSecurityEventClose(securityEvent)">{{ $t('Close Event') }}</b-button>
              </span>
            </template>
            <template v-slot:empty>
              <base-table-empty :isLoading="isLoadingSecurityEvents" text="">{{ $t('No security events found') }}</base-table-empty>
            </template>
          </b-table>
          
          <div class="mt-3">
            <div class="border-top pt-3">
              <b-button class="mr-1" variant="outline-primary" :disabled="isLoadingSecurityEvents || !hasOpenSecurityEvents" @click="closeSecurityEvents()">{{ $t('Close all security events') }}</b-button>
            </div>
          </div>    
        </b-tab>
      </b-tabs>
    </base-form> 
  </b-form>
</template>
<script>
import {
  BaseForm,
  BaseFormButtonBar,
  BaseFormGroup,
  BaseFormTab,
  BaseTableEmpty
} from '@/components/new/'
import {
  FormGroupPid,
  FormGroupPassword,
  FormGroupLoginRemaining,
  FormGroupEmail,
  FormGroupSponsor,
  FormGroupLanguage,
  FormGroupGender,
  FormGroupTitle,
  FormGroupFirstname,
  FormGroupLastname,
  FormGroupNickname,
  FormGroupCompany,
  FormGroupTelephone,
  FormGroupCellPhone,
  FormGroupWorkPhone,
  FormGroupApartmentNumber,
  FormGroupBuildingNumber,
  FormGroupRoomNumber,
  FormGroupAddress,
  FormGroupAnniversary,
  FormGroupBirthday,
  FormGroupPsk,
  FormGroupNotes,
  FormGroupCustomField1,
  FormGroupCustomField2,
  FormGroupCustomField3,
  FormGroupCustomField4,
  FormGroupCustomField5,
  FormGroupCustomField6,
  FormGroupCustomField7,
  FormGroupCustomField8,
  FormGroupCustomField9,

  InputGroupValidFrom,
  InputGroupExpiration,
  FormGroupActions
} from './'

const components = {
  BaseForm,
  BaseFormButtonBar,
  BaseFormGroup,
  BaseFormTab,
  BaseTableEmpty,
  
  FormGroupPid,
  FormGroupEmail,
  FormGroupSponsor,
  FormGroupLanguage,
  FormGroupGender,
  FormGroupTitle,
  FormGroupFirstname,
  FormGroupLastname,
  FormGroupNickname,
  FormGroupCompany,
  FormGroupTelephone,
  FormGroupCellPhone,
  FormGroupWorkPhone,
  FormGroupApartmentNumber,
  FormGroupBuildingNumber,
  FormGroupRoomNumber,
  FormGroupAddress,
  FormGroupAnniversary,
  FormGroupBirthday,
  FormGroupPsk,
  FormGroupNotes,
  
  FormGroupPassword,
  FormGroupLoginRemaining,

  InputGroupValidFrom,
  InputGroupExpiration,
  FormGroupActions,

  FormGroupCustomField1,
  FormGroupCustomField2,
  FormGroupCustomField3,
  FormGroupCustomField4,
  FormGroupCustomField5,
  FormGroupCustomField6,
  FormGroupCustomField7,
  FormGroupCustomField8,
  FormGroupCustomField9,
}

const props = {
  pid: {
    type: String    
  }
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import {
  nodeFields as _nodeFields,
  securityEventFields as _securityEventsFields
} from '../_config/'
import { single as schemaFn } from '../schema'

const setup = (props, context) => {
  
  const {
    pid    
  } = toRefs(props)
  
  const { root: { $router, $store } = {} } = context

  const rootRef = ref(null)
  const form = ref({})
  const schema = computed(() => schemaFn(props, form.value))
  const tabIndex = ref(0)
  const isDefaultUser = computed(() => {
    const { pid } = form.value 
    return pid === 'default'
  })
  const isExpiration = computed(() => !!form.value.expiration)
  const isLoading = computed(() => $store.getters['$_users/isLoading'])
  const isValid = useDebouncedWatchHandler(
    [form],
    () => (
      !rootRef.value ||
      Array.prototype.slice.call(rootRef.value.querySelectorAll('.is-invalid'))
        .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
        .length === 0
    )
  )
  
  const nodes = ref([])
  const hasNodes = computed(() => Array.isArray(nodes.value) && nodes.value.length > 0)
  const isLoadingNodes = computed(() => $store.getters['$_users/isLoadingNodes'])
  const nodeFields = ref(_nodeFields.map(field => ({ visible: false, ...field })))
  const nodeSortBy = ref('status')
  const nodeSortDesc = ref(false)
  const onNodeFieldToggle = column => {
    const index = nodeFields.value.findIndex(field => field.key === column.key)
    nodeFields.value[index].visible = !nodeFields.value[index].visible
  }
  const visibleNodeFields = computed(() => nodeFields.value.filter(field => field.visible || field.locked))
  const onNodesUnassign = () => $store.dispatch('$_users/unassignUserNodes', pid.value)
  
  const securityEvents = ref([])
  const hasOpenSecurityEvents = computed(() => Array.isArray(securityEvents.value) && securityEvents.value.findIndex(securityEvent => securityEvent.status === 'open') > -1)
  const isLoadingSecurityEvents = computed(() => $store.getters['$_users/isLoadingSecurityEvents'])
  const securityEventFields = ref(_securityEventsFields.map(field => ({ visible: false, ...field })))
  const securityEventSortBy = ref('start_date')
  const securityEventSortDesc = ref(true)
  const onSecurityEventClose = () => {
    // TODO
  }
  const onSecurityEventCloseAll = () => {
    // TODO
  }
  
  const onResetPassword = () => {
    const { password, login_remaining } = form.value
    const { id: tenant_id } = $store.state.session.tenant
    const data = {
      pid: pid.value,
      tenant_id,
      password,
      login_remaining
    }
    return $store.dispatch('$_users/updatePassword', data)
  }
  
  const onInit = () => {
    $store.dispatch('$_users/getUserNodes', pid.value).then(_nodes => {
      nodes.value = _nodes
    })
    $store.dispatch('$_users/getUserSecurityEvents', pid.value).then(_securityEvents => {
      securityEvents.value = _securityEvents
    })
    $store.dispatch('$_users/refreshUser', pid.value).then(user => {
      form.value = { ...user }
    })
  }
  onInit()
  
  const onClose = () => $router.back()
  
  const onReset = onInit
  
  const onSave = () => {
    $store.dispatch('$_users/updateUser', form.value).then(() => {
      if (form.value.expiration) // has password
        $store.dispatch('$_users/updatePassword', Object.assign({ quiet: true }, form.value))
    })
  }
  
  const onRemove = () => {
    $store.dispatch('$_users/deleteUser', pid.value).then(() => {
      $router.push('/users/search')
    })    
  }
  
  return {
    rootRef,
    form,
    schema,
    tabIndex,
    isDefaultUser,
    isExpiration,
    isLoading,
    isValid,
    
    nodes,
    hasNodes,
    isLoadingNodes,
    nodeFields,
    nodeSortBy,
    nodeSortDesc,
    onNodeFieldToggle,
    visibleNodeFields,
    onNodesUnassign,
    
    securityEvents,
    hasOpenSecurityEvents,
    isLoadingSecurityEvents,
    securityEventFields,
    securityEventSortBy,
    securityEventSortDesc,
    onSecurityEventClose,
    onSecurityEventCloseAll,
    
    onResetPassword,
    onClose,
    onRemove,
    onReset,
    onSave
  }
}

// @vue/component
export default {
  name: 'the-form-update',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
