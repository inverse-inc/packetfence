<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :labelCols="labelCols"
    :label="columnLabel"
  >
      <b-row no-gutters class="border-bottom">
        <b-col cols="3">
          <input-toggle-unreg v-model="unreg"/>
        </b-col>
      </b-row>

      <b-row no-gutters class="border-bottom">
        <b-col cols="3">
          <input-toggle-autoreg v-model="autoreg"/>
        </b-col>
        <b-collapse :visible="autoreg" class="col-sm-9 mt-3">

          <form-group-target-category namespace="target_category"
            :column-label="$t('Target Role')"
          />

          <form-group-access-duration namespace="access_duration"
            :column-label="$t('Access Duration')"
          />

        </b-collapse>
      </b-row>

      <b-row no-gutters class="border-bottom">
        <b-col cols="3">
          <input-toggle-isolate v-model="isolate"/>
        </b-col>
        <b-collapse :visible="isolate" class="col-sm-9 mt-3">

          <form-group-vlan namespace="vlan"
            :column-label="$t('Role while isolated')"
          />

          <form-group-template namespace="template"
            :column-label="$t('Template to use')"
          />

          <form-group-button-text namespace="button_text"
            :column-label="$t('Button Text')"
            :text="$t('Text displayed on the security event form to hosts.')"
          />

          <form-group-redirect-url namespace="redirect_url"
            :column-label="$t('Redirection URL')"
            :text="$t('Destination URL where PacketFence will forward the device. By default it will use the Redirection URL from the connection profile configuration.')"
          />

          <form-group-auto-enable namespace="auto_enable"
            :column-label="$t('Auto Enable')"
            :text="$t('Specifies if a host can self remediate the security event (enable network button) or if they can not and must call the help desk.')"
          />

          <form-group-max-enable namespace="max_enable"
            :column-label="$t('Max Enables')"
            :text="$t('Number of times a host will be able to try and self remediate before they are locked out and have to call the help desk. This is useful for users who just click through security event pages.')"
          />

        </b-collapse>
      </b-row>

      <b-row no-gutters class="border-bottom">
        <b-col cols="3">
          <input-toggle-email-admin v-model="email_admin"/>
        </b-col>
      </b-row>

      <b-row no-gutters class="border-bottom">
        <b-col cols="3">
          <input-toggle-email-user v-model="email_user"/>
        </b-col>
        <b-collapse :visible="email_user" class="col-sm-9 mt-3">

          <form-group-user-mail-message namespace="user_mail_message"
            :column-label="$t('Additional message')"
          />

        </b-collapse>
      </b-row>

      <b-row no-gutters class="border-bottom">
        <b-col cols="3">
          <input-toggle-external v-model="external"/>
        </b-col>
        <b-collapse :visible="external" class="col-sm-9 mt-3">

          <form-group-external-command namespace="external_command"
            :column-label="$t('Script path')"
            :text="$t('Script need to be readable and executable by pf user.')"
          />

          <div class="alert alert-warning">
            <p><strong>{{ $i18n.t('Note:') }}</strong> {{ $i18n.t('You can use the following variables in your script launch command:') }}</p>
            <ul>
              <li><code>$mac</code>: {{ $i18n.t('MAC address of the endpoint') }}</li>
              <li><code>$ip</code>: {{ $i18n.t('IP address of the endpoint') }}</li>
              <li><code>$vid</code>: {{ $i18n.t('ID of the security event') }}</li>
            </ul>
          </div>

        </b-collapse>
      </b-row>

      <b-row no-gutters class="border-bottom">
        <b-col cols="3">
          <input-toggle-close v-model="close"/>
        </b-col>
        <b-collapse :visible="close" class="col-sm-9 mt-3">

          <form-group-v-close namespace="vclose"
            :column-label="$t('Security event to close')"
          />

        </b-collapse>
      </b-row>
  </b-form-group>
</template>
<script>
import {
  BaseFormGroupChosenOne    as FormGroupAccessDuration,
  BaseFormGroupToggleNY     as FormGroupAutoEnable,
  BaseFormGroupInput        as FormGroupButtonText,
  BaseFormGroupInput        as FormGroupExternalCommand,
  BaseFormGroupInputNumber  as FormGroupMaxEnable,
  BaseFormGroupInput        as FormGroupRedirectUrl,
  BaseFormGroupChosenOne    as FormGroupTargetCategory,
  BaseFormGroupChosenOne    as FormGroupTemplate,
  BaseFormGroupTextarea     as FormGroupUserMailMessage,
  BaseFormGroupChosenOne    as FormGroupVClose,
  BaseFormGroupChosenOne    as FormGroupVlan,
} from '@/components/new'
import BaseInputToggleAutoreg from './BaseInputToggleAutoreg'
import BaseInputToggleClose from './BaseInputToggleClose'
import BaseInputToggleEmailAdmin from './BaseInputToggleEmailAdmin'
import BaseInputToggleEmailUser from './BaseInputToggleEmailUser'
import BaseInputToggleExternal from './BaseInputToggleExternal'
import BaseInputToggleIsolate from './BaseInputToggleIsolate'
import BaseInputToggleUnreg from './BaseInputToggleUnreg'

const components = {
  FormGroupAccessDuration,
  FormGroupAutoEnable,
  FormGroupButtonText,
  FormGroupExternalCommand,
  FormGroupMaxEnable,
  FormGroupRedirectUrl,
  FormGroupTargetCategory,
  FormGroupTemplate,
  FormGroupUserMailMessage,
  FormGroupVClose,
  FormGroupVlan,

  InputToggleAutoreg:     BaseInputToggleAutoreg,
  InputToggleClose:       BaseInputToggleClose,
  InputToggleEmailAdmin:  BaseInputToggleEmailAdmin,
  InputToggleEmailUser:   BaseInputToggleEmailUser,
  InputToggleExternal:    BaseInputToggleExternal,
  InputToggleIsolate:     BaseInputToggleIsolate,
  InputToggleUnreg:       BaseInputToggleUnreg,
}

import { customRef, inject, ref, unref, watch } from '@vue/composition-api'
import { getFormNamespace, setFormNamespace } from '@/composables/useInputValue'
import { useFormGroupProps as props } from '@/composables/useFormGroup'

const setup = () => {

  const form = inject('form', ref({}))

  const actionsValue = customRef((track, trigger) => ({
    get() {
      track()
      return getFormNamespace(['actions'], unref(form)) || []
    },
    set(newValue) {
      setFormNamespace(['actions'], unref(form), newValue)
      trigger()
    }
  }))

  const add = (action) => {
    remove(action) // remove duplicates
    actionsValue.value = [ ...actionsValue.value, action ]
  }

  const remove = (action) => {
    actionsValue.value = actionsValue.value.filter(a => a !== action)
  }

  const unreg = customRef((track, trigger) => ({
    get() {
      track()
      return actionsValue.value.includes('unreg')
    },
    set(newValue) {
      if (newValue) {
        add('unreg')
        remove('autoreg')
        remove('role')
      }
      else
        remove('unreg')
      trigger()
    }
  }))

  const autoreg = customRef((track, trigger) => ({
    get() {
      track()
      return actionsValue.value.includes('autoreg')
    },
    set(newValue) {
      if (newValue) {
        add('autoreg')
        remove('unreg')
        if (form.value.target_category)
          add('role')
      }
      else {
        remove('autoreg')
        remove('role')
      }
      trigger()
    }
  }))

  const isolate = customRef((track, trigger) => ({
    get() {
      track()
      return actionsValue.value.includes('reevaluate_access')
    },
    set(newValue) {
      if (newValue)
        add('reevaluate_access')
      else
        remove('reevaluate_access')
      trigger()
    }
  }))

  const email_admin = customRef((track, trigger) => ({
    get() {
      track()
      return actionsValue.value.includes('email_admin')
    },
    set(newValue) {
      if (newValue)
        add('email_admin')
      else
        remove('email_admin')
      trigger()
    }
  }))

  const email_user = customRef((track, trigger) => ({
    get() {
      track()
      return actionsValue.value.includes('email_user')
    },
    set(newValue) {
      if (newValue)
        add('email_user')
      else
        remove('email_user')
      trigger()
    }
  }))

  const external = customRef((track, trigger) => ({
    get() {
      track()
      return actionsValue.value.includes('external')
    },
    set(newValue) {
      if (newValue)
        add('external')
      else
        remove('external')
      trigger()
    }
  }))

  const close = customRef((track, trigger) => ({
    get() {
      track()
      return actionsValue.value.includes('close')
    },
    set(newValue) {
      if (newValue)
        add('close')
      else
        remove('close')
      trigger()
    }
  }))

  watch(
    () => form.value.target_category,
    target_category => {
      if (target_category)
        add('role')
      else
        remove('role')
    }
  )

  return {
    unreg,
    autoreg,
    isolate,
    email_admin,
    email_user,
    external,
    close
  }
}

// @vue/component
export default {
  name: 'base-form-group-actions',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
