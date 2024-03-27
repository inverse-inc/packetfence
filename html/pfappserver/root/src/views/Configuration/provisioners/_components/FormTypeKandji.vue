<template>
  <base-form
    :form="form"
    :isLoading="isLoading"
    :meta="meta"
    :schema="schema"
  >
    <form-group-identifier :column-label="$i18n.t('Provisioner name')"
                           :disabled="!isNew && !isClone"
                           namespace="id"
    />

    <form-group-description :column-label="$i18n.t('Description')"
                            namespace="description"
    />

    <form-group-enforce :column-label="$i18n.t('Enforce')"
                        :text="$i18n.t('Whether or not the provisioner should be enforced. This will trigger checks to validate the device is compliant with the provisioner during RADIUS authentication and on the captive portal.')"
                        disabled-value="disabled"
                        enabled-value="enabled"
                        namespace="enforce"
    />

    <form-group-auto-register :column-label="$i18n.t('Auto register')"
                              :text="$i18n.t('Whether or not devices should be automatically registered on the network if they are authorized in the provisioner.')"
                              disabled-value="disabled"
                              enabled-value="enabled"
                              namespace="autoregister"
    />

    <form-group-apply-role :column-label="$i18n.t('Apply role')"
                           :text="$i18n.t('When enabled, this will apply the configured role to the endpoint if it is authorized in the provisioner.')"
                           disabled-value="disabled"
                           enabled-value="enabled"
                           namespace="apply_role"
    />

    <form-group-role-to-apply :column-label="$i18n.t('Role to apply')"
                              :text="$i18n.t(`When 'Apply role' is enabled, this defines the role to apply when the device is authorized with the provisioner.`)"
                              namespace="role_to_apply"
    />

    <form-group-category :column-label="$i18n.t('Roles')"
                         :text="$i18n.t('Nodes with the selected roles will be affected.')"
                         namespace="category"
    />

    <form-group-oses :column-label="$i18n.t('OS')"
                     :text="$i18n.t('Nodes with the selected OS will be affected.')"
                     namespace="oses"
    />

    <form-group-rules :column-label="$i18n.t('Rules')"
                     :text="$i18n.t('Rules to apply.')"
                     namespace="rules"
    />

    <form-group-api-token :column-label="$i18n.t('API token')"
                          namespace="api_token"
    />

    <form-group-protocol :column-label="$i18n.t('Protocol')"
                         namespace="protocol"
    />

    <form-group-host :column-label="$i18n.t('Host')"
                     namespace="host"
    />

    <form-group-port :column-label="$i18n.t('Port')"
                     namespace="port"
    />

    <form-group-enroll-url :column-label="$i18n.t('Enroll URL')"
                           :text="$i18n.t('Which URL the endpoints should use to enroll. This should point to the Kandji self-service portal. When empty, it will default to the /enroll path on the protocol+host+port defined above which is Kandji\'s default')"
                           namespace="enroll_url"
    />

  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupApiToken,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupEnrollUrl,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRoleToApply,
  FormGroupRules,
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupApiToken,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupEnrollUrl,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRoleToApply,
  FormGroupRules,
}

// @vue/component
export default {
  name: 'form-type-kandji',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
