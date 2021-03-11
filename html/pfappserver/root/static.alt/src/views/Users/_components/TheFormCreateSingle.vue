<template>
  <b-form @submit.prevent ref="rootRef">
    <base-form
      :form="form"
      :schema="schema"
      :isLoading="isLoading"
      class="pt-0"
    >
      <form-group-pid-overwrite namespace="pid_overwrite"
        :column-label="$t('Username (PID) overwrite')"
        :text="$t('Overwrite the username (PID) if it already exists.')"
      />

      <!--- pid w/ domain_name -->
      <form-group-pid v-if="domainName"
        namespace="pid"
        :column-label="$i18n.t('Username (PID)')"
        :text="$t('The username to use for login to the captive portal. The tenants domain_name will be appended to the username.')"
      >
        <template v-slot:append>
          <b-button disabled variant="link" v-b-tooltip.hover.top.d300 :title="$t('Domain Name will be appended.')">{{ domainName }}</b-button>
        </template>
      </form-group-pid>

      <!-- pid wo/ domain_name -->
      <form-group-pid v-else
        namespace="pid"
        :column-label="$i18n.t('Username (PID)')"
        :text="$t('The username to use for login to the captive portal.')"
      />

      <form-group-password namespace="password"
        :column-label="$t('Password')"
      />

      <form-group-login-remaining namespace="login_remaining"
        :column-label="$t('Login remaining')"
        :text="$t('Leave empty to allow unlimited logins.')"
      />

      <form-group-email namespace="email"
        :column-label="$t('Email')"
      />

      <form-group-sponsor namespace="sponsor"
        :column-label="$t('Sponsor')"
        :text="$t('If no sponsor is defined the current user will be used.')"
        :placeholder="$store.state['session'].username"
      />

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
            isNew
            :isLoading="isLoading"
            isSaveable
            :isValid="isValid"
            :formRef="rootRef"
            @close="onClose"
            @reset="onReset"
            @save="onCreate"
          />
        </div>
      </div>
    </base-form>
    <users-preview-modal v-model="showUsersPreviewModal" store-name="$_users"/>
  </b-form>
</template>
<script>
import {
  BaseForm,
  BaseFormButtonBar,
  BaseFormGroup
} from '@/components/new/'
import {
  FormGroupPidOverwrite,
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
import UsersPreviewModal from './UsersPreviewModal'

const components = {
  BaseForm,
  BaseFormButtonBar,
  BaseFormGroup,

  FormGroupPidOverwrite,
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
  FormGroupActions,
  UsersPreviewModal
}

import { computed, ref } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import { single as schemaFn } from '../schema'

const defaults = {
  pid_overwrite: 0,
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
  psk: '',
  notes: '',
  custom_field_1: '',
  custom_field_2: '',
  custom_field_3: '',
  custom_field_4: '',
  custom_field_5: '',
  custom_field_6: '',
  custom_field_7: '',
  custom_field_8: '',
  custom_field_9: '',
  actions: [
    { type: 'set_access_level' }
  ]
}

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const rootRef = ref(null)
  const form = ref({ ...defaults }) // dereferenced
  const schema = computed(() => schemaFn(props, form.value))
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

  const domainName = computed(() => {
    const { domain_name = null } = $store.getters['session/tenantMask'] || {}
    return domain_name
  })

  const onClose = () => {
    $router.push({ name: 'users' })
  }

  const showUsersPreviewModal = ref(false)
  const onCreate = () => {
    if (!isValid.value)
      return
    showUsersPreviewModal.value = false
    const _form = form.value
    if (domainName.value) // append domainName to pid when available (tenant)
        _form.pid = `${_form.pid}@${domainName.value}`
    $store.dispatch('$_users/createUser', _form).then(() => {
      $store.dispatch('$_users/createPassword', Object.assign({ quiet: true }, _form)).then(() => {
        $store.commit('$_users/CREATED_USERS_REPLACED', [_form])
        showUsersPreviewModal.value = true
      })
    })
  }

  const onReset = () => {
    form.value = { ...defaults } // dereferenced
  }

  return {
    rootRef,
    form,
    schema,
    isLoading,
    isValid,
    domainName,
    onClose,
    onCreate,
    onReset,
    showUsersPreviewModal
  }
}

// @vue/component
export default {
  name: 'the-form-create-single',
  inheritAttrs: false,
  components,
  setup
}
</script>
