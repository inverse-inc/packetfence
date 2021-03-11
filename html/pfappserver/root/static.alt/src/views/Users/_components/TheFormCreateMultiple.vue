<template>
  <b-form @submit.prevent ref="rootRef">
    <base-form
      :form="form"
      :schema="schema"
      :isLoading="isLoading"
      class="pt-0"
    >
      <b-alert show variant="info" v-html="$t('The usernames are constructed from the <b>prefix</b> and the <b>quantity</b>. For example, setting the prefix to <i>guest</i> and the quantity to <i>3</i> creates usernames <i>guest1</i>, <i>guest2</i> and <i>guest3</i>. Random passwords will be created.')"></b-alert>

      <form-group-pid-overwrite namespace="pid_overwrite"
        :column-label="$t('Username (PID) overwrite')"
        :text="$t('Overwrite the username (PID) if it already exists.')"
      />
      
      <form-group-prefix namespace="prefix"
        :column-label="$t('Username Prefix')"
      />
      
      <form-group-quantity namespace="quantity"
        :column-label="$t('Quantity')"
      />

      <form-group-password-options v-model="passwordOptions"
        min="6" max="64"
        :column-label="$i18n.t('Password')"
        :text="$i18n.t('Random passwords will be created.')"
      />

      <form-group-login-remaining namespace="login_remaining"
        :column-label="$t('Login remaining')"
        :text="$t('Leave empty to allow unlimited logins.')"
      />
      
      <form-group-firstname namespace="firstname"
        :column-label="$t('Firstname')"
      />

      <form-group-lastname namespace="lastname"
        :column-label="$t('Lastname')"
      />

      <form-group-company namespace="company"
        :column-label="$t('Company')"
      />
      
      <form-group-notes namespace="notes"
        :column-label="$t('Notes')"
      />
      
      <base-form-group
        :column-label="$t('Registration Window')"
      >
        <input-group-valid-from namespace="valid_from"
          class="flex-grow-1" />
        <b-button variant="link" disabled><icon name="long-arrow-alt-right"></icon></b-button>
        <input-group-expiration namespace="expiration"
          class="flex-grow-1" />
      </base-form-group>

      <form-group-actions namespace="actions"
        :column-label="$t('Actions')"
      />

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
  FormGroupPrefix,
  FormGroupQuantity,
  FormGroupLoginRemaining,
  FormGroupFirstname,
  FormGroupLastname,
  FormGroupCompany,
  FormGroupNotes,
  FormGroupPasswordOptions,
  
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
  FormGroupPrefix,
  FormGroupQuantity,
  FormGroupLoginRemaining,
  FormGroupFirstname,
  FormGroupLastname,
  FormGroupCompany,
  FormGroupNotes,
  FormGroupPasswordOptions,

  InputGroupValidFrom,
  InputGroupExpiration,
  FormGroupActions,
  UsersPreviewModal
}

import { computed, ref } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import { multiple as schemaFn } from '../schema'
import i18n from '@/utils/locale'
import password from '@/utils/password'
import { passwordOptions as _passwordOptions } from '../_config/'

const defaults = {
  pid_overwrite: 1,
  actions: [
    { type: 'set_access_level' }
  ]
}

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const rootRef = ref(null)
  const form = ref({ ...defaults }) // dereferenced
  const schema = computed(() => schemaFn(props, form.value, domainName.value))
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
    return domain_name || 'satkunas'
  })

  const onClose = () => {
    $router.push({ name: 'users' })
  }

  const showUsersPreviewModal = ref(false)
  const onCreate = () => {
    if (!isValid.value)
      return
    showUsersPreviewModal.value = false
    const base = {
      ...form.value,
      quiet: true
    }
    let createdUsers = []
    let promises = []
    for (let i = 0; i < base.quantity; i++) {
      let _form = {
        ...base,
        pid: (domainName.value) // has tenant?
          ? `${base.prefix}${(i + 1)}@${domainName.value}`  // append domainName to pid
          : `${base.prefix}${(i + 1)}`,
        password: password.generate(passwordOptions.value)
      }
      promises.push($store.dispatch('$_users/exists', _form.pid).then(() => {
        // user exists
        $store.dispatch('$_users/updateUser', _form).then(() => {
          return $store.dispatch('$_users/updatePassword', _form).then(() => {
            createdUsers.push(_form)
          })
        })
      }).catch(() => {
        // user not exist
        $store.dispatch('$_users/createUser', _form).then(() => {
          return $store.dispatch('$_users/createPassword', _form).then(() => {
            createdUsers.push(_form)
          })
        })
      }))
    }
    Promise.all(promises).then(values => {
      $store.dispatch('notification/info', {
        message: i18n.t('{quantity} users created', { quantity: values.length }),
        success: null,
        skipped: null,
        failed: null
      })
      $store.commit('$_users/CREATED_USERS_REPLACED', createdUsers)
      showUsersPreviewModal.value = true
    })
  }

  const onReset = () => {
    form.value = { ...defaults } // dereferenced
  }
  
  const passwordOptions = ref(_passwordOptions)

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
    showUsersPreviewModal,
    passwordOptions
  }
}

// @vue/component
export default {
  name: 'the-form-create-multiple',
  inheritAttrs: false,
  components,
  setup
}
</script>
