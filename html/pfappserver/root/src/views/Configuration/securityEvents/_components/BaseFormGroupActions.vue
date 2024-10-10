<template>
  <b-form-group ref="form-group"
                class="base-form-group"
                :class="{
      'mb-0': !columnLabel
    }"
                :content-cols="contentCols"
                :content-cols-sm="contentColsSm"
                :content-cols-md="contentColsMd"
                :content-cols-lg="contentColsLg"
                :content-cols-xl="contentColsXl"
                :label="columnLabel"
                :label-cols="labelCols"
                :label-cols-sm="labelColsSm"
                :label-cols-md="labelColsMd"
                :label-cols-lg="labelColsLg"
                :label-cols-xl="labelColsXl"
  >
    <b-row no-gutters class="border-bottom">
      <b-col cols="3" class="action-col">
        <base-input-switch :onChange="unregOnChange" :isLocked="isLocked" :value="unreg"/>
        <base-label>Unregister</base-label>
      </b-col>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col cols="3" class="action-col">
        <base-input-switch label="Register" :onChange="autoregOnChange"
                           :isLocked="isLocked" :value="autoreg"/>
        <base-label>Register</base-label>
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
      <b-col cols="3" class="action-col">
        <base-input-switch :onChange="reevaluateOnChange" :isLocked="isLocked" :value="reevaluate"/>
        <base-label>Isolate</base-label>
      </b-col>
      <b-collapse :visible="reevaluate" class="col-sm-9 mt-3">

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
      <b-col cols="3" class="action-col">
        <base-input-switch :onChange="emailAdminOnChange" :isLocked="isLocked"
                           :value="emailAdmin"/>
        <base-label>Email administrator</base-label>
      </b-col>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col cols="3" class="action-col">
        <base-input-switch :onChange="emailUserOnChange" :isLocked="isLocked"
                           :value="emailUser"/>
        <base-label>Email endpoint owner</base-label>
      </b-col>
      <b-collapse :visible="emailUser" class="col-sm-9 mt-3">

        <form-group-user-mail-message namespace="user_mail_message"
                                      :column-label="$t('Additional message')"
        />

      </b-collapse>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col cols="3" class="action-col">
        <base-input-switch :onChange="emailRecipientOnChange" :isLocked="isLocked"
                           :value="emailRecipient"/>
        <base-label>Email Recipient</base-label>
      </b-col>
      <b-collapse :visible="emailRecipient" class="col-sm-9 mt-3">

        <form-group-recipient-email namespace="recipient_email"
                                    :column-label="$t('Email address')"
        />
        <form-group-recipient-message namespace="email_recipient_message"
                                      :column-label="$t('Additional message')"
        />
        <form-group-recipient-template-message namespace="recipient_template_email"
                                               :column-label="$t('Template to use')"
        />

      </b-collapse>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col cols="3" class="action-col">
        <base-input-switch :onChange="externalAccessOnChange" :isLocked="isLocked"
                           :value="externalAccess"/>
        <base-label>Execute script</base-label>
      </b-col>
      <b-collapse :visible="externalAccess" class="col-sm-9 mt-3">

        <form-group-external-command namespace="external_command"
                                     :column-label="$t('Script path')"
                                     :text="$t('Script need to be readable and executable by pf user.')"
        />

        <div class="alert alert-warning">
          <p><strong>{{ $i18n.t('Note:') }}</strong>
            {{ $i18n.t('You can use the following variables in your script launch command:') }}</p>
          <ul>
            <li><code>$mac</code>: {{ $i18n.t('MAC address of the endpoint') }}</li>
            <li><code>$ip</code>: {{ $i18n.t('IP address of the endpoint') }}</li>
            <li><code>$vid</code>: {{ $i18n.t('ID of the security event') }}</li>
          </ul>
        </div>

      </b-collapse>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col cols="3" class="action-col">
        <base-input-switch :onChange="closeOnChange" :isLocked="isLocked"
                           :value="close"/>
        <base-label>Close another security event</base-label>
      </b-col>
      <b-collapse :visible="close" class="col-sm-9 mt-3">

        <form-group-v-close namespace="vclose"
                            :column-label="$t('Security event to close')"
        />

      </b-collapse>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col cols="3" class="action-col">
        <base-input-switch :onChange="enforceProvisioningOnChange" :isLocked="isLocked" :value="enforceProvisioning"/>
        <base-label>Enforce Provisioning</base-label>
      </b-col>
    </b-row>

  </b-form-group>
</template>
<script>
import {
  BaseFormGroupChosenOne as FormGroupAccessDuration,
  BaseFormGroupToggleNY as FormGroupAutoEnable,
  BaseFormGroupInput as FormGroupButtonText,
  BaseFormGroupInput as FormGroupExternalCommand,
  BaseFormGroupInputNumber as FormGroupMaxEnable,
  BaseFormGroupInput as FormGroupRedirectUrl,
  BaseFormGroupChosenOne as FormGroupTargetCategory,
  BaseFormGroupChosenOne as FormGroupTemplate,
  BaseFormGroupTextarea as FormGroupUserMailMessage,
  BaseFormGroupInput as FormGroupRecipientEmail,
  BaseFormGroupTextarea as FormGroupRecipientMessage,
  BaseFormGroupInput as FormGroupRecipientTemplateMessage,
  BaseFormGroupChosenOne as FormGroupVClose,
  BaseFormGroupChosenOne as FormGroupVlan, BaseLabel,
} from '@/components/new'

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
  FormGroupRecipientEmail,
  FormGroupRecipientMessage,
  FormGroupRecipientTemplateMessage,
  FormGroupVlan,
  BaseInputSwitch,
  BaseLabel,
}

import {computed, customRef, inject, ref, unref, watch} from '@vue/composition-api'
import {getFormNamespace, setFormNamespace} from '@/composables/useInputValue'
import {useFormGroupProps as props} from '@/composables/useFormGroup'
import BaseInputSwitch from '@/components/new/BaseInputSwitch';

const setup = () => {

  const isLoading = inject('isLoading', ref(false))
  const isReadonly = inject('isReadonly', ref(false))
  const isLocked = computed(() => unref(isReadonly) || unref(isLoading))


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
    actionsValue.value = [...actionsValue.value, action]
  }

  const remove = (action) => {
    actionsValue.value = actionsValue.value.filter(a => a !== action)
  }

  const unregKey = 'unreg'
  const autoregKey = 'autoreg'
  const roleKey = 'role'
  const reevaluateKey = 'reevaluate_access'
  const emailAdminKey = 'email_admin'
  const emailUserKey = 'email_user'
  const emailRecipientKey = 'email_recipient'
  const externalKey = 'external'
  const closeKey = 'close'
  const enforceProvisioningKey = 'enforce_provisioning'

  const unreg = computed(() => unref(actionsValue).includes(unregKey))

  const unregOnChange = (newValue) => {
    if (newValue) {
      add(unregKey)
      remove(autoregKey)
      remove(roleKey)
    } else {
      remove(unregKey)
    }
  }

  const autoreg = computed(() => unref(actionsValue).includes(autoregKey))
  const autoregOnChange = (newValue) => {
    if (newValue) {
      add(autoregKey)
      remove(unregKey)
      if (form.value.target_category)
        add(roleKey)
    } else {
      remove(autoregKey)
      remove(roleKey)
    }
  }


  const reevaluate = computed(() => unref(actionsValue).includes(reevaluateKey))

  const reevaluateOnChange = (newValue) => {
    if (newValue)
      add(reevaluateKey)
    else
      remove(reevaluateKey)
  }

  const emailAdmin = computed(() => unref(actionsValue).includes(emailAdminKey))

  const emailAdminOnChange = (newValue) => {
    if (newValue)
      add(emailAdminKey)
    else
      remove(emailAdminKey)
  }

  const emailUser = computed(() => unref(actionsValue).includes(emailUserKey))

  const emailUserOnChange = (newValue) => {
    if (newValue)
      add(emailUserKey)
    else
      remove(emailUserKey)
  }

  const emailRecipient = computed(() => unref(actionsValue).includes(emailRecipientKey))

  const emailRecipientOnChange = (newValue) => {
    if (newValue)
      add(emailRecipientKey)
    else
      remove(emailRecipientKey)
  }

  const externalAccess = computed(() => unref(actionsValue).includes(externalKey))

  const externalAccessOnChange = (newValue) => {
    if (newValue)
      add(externalKey)
    else
      remove(externalKey)
  }

  const close = computed(() => unref(actionsValue).includes(closeKey))

  const closeOnChange = (newValue) => {
    if (newValue)
      add(closeKey)
    else
      remove(closeKey)
  }

  const enforceProvisioning = computed(() => unref(actionsValue).includes(enforceProvisioningKey))

  const enforceProvisioningOnChange = (newValue) => {
    if (newValue) {
      add(enforceProvisioningKey)
    } else {
      remove(enforceProvisioningKey)
    }
  }

  watch(
    () => form.value.target_category,
    target_category => {
      if (target_category)
        add(roleKey)
      else
        remove(roleKey)
    }
  )

  return {
    isLocked,
    unreg,
    unregOnChange,
    autoreg,
    autoregOnChange,
    reevaluate,
    reevaluateOnChange,
    emailAdmin,
    emailAdminOnChange,
    emailUser,
    emailUserOnChange,
    emailRecipient,
    emailRecipientOnChange,
    externalAccess,
    externalAccessOnChange,
    close,
    closeOnChange,
    enforceProvisioning,
    enforceProvisioningOnChange,
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
<style>
.action-col {
  display: flex;
}

.action-col div.base-label {
  margin-left: 10px;
}

</style>
