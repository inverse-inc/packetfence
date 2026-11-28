<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
                           :column-label="$i18n.t('Name')"
    />

    <form-group-ip namespace="ip"
                   :column-label="$i18n.t('Hostname or IP Address')"
    />

    <form-group-username namespace="username"
                         :column-label="$i18n.t('Username')"
    />

    <form-group-password namespace="password"
                         :column-label="$i18n.t('Password')"
    />

    <form-group-port namespace="port"
                     :column-label="$i18n.t('SSH port of the GMP service')"
                     :text="$i18n.t('Port of the SSH service giving access to the Greenbone Management Protocol (GMP).')"
    />

    <form-group-openvas-ssh-username namespace="openvas_ssh_username"
                                     :column-label="$i18n.t('SSH username')"
                                     :text="$i18n.t('SSH user giving access to the Greenbone Management Protocol (GMP) on the OpenVAS server.')"
    />

    <form-group-openvas-ssh-password namespace="openvas_ssh_password"
                                     :column-label="$i18n.t('SSH password')"
                                     :text="$i18n.t('Password of the SSH user.')"
    />

    <form-group-openvas-alert-identifier namespace="openvas_alertid"
                                         :column-label="$i18n.t('Alert ID')"
                                         :text="$i18n.t('ID of the alert configuration on the OpenVAS server.')"
    />
    <form-group-openvas-config-identifier namespace="openvas_configid"
                                          :column-label="$i18n.t('Scan config ID')"
                                          :text="$i18n.t('ID of the scanning configuration on the OpenVAS server.')"
    />
    <form-group-openvas-scanner-identifier namespace="openvas_scannerid"
                                           :column-label="$i18n.t('Scanner ID')"
                                           :text="$i18n.t('ID of the scanner on the OpenVAS server.')"
    />
    <form-group-openvas-port-list-identifier namespace="openvas_portlistid"
                                             :column-label="$i18n.t('Port list ID')"
                                             :text="$i18n.t('ID of the port list on the OpenVAS server.')"
    />

    <form-group-openvas-delete-scans namespace="openvas_delete_scans"
                                     :column-label="$i18n.t('Delete scans')"
                                     :text="$i18n.t('Delete the task, its report and the target from the OpenVAS server once the report is processed.')"
                                     enabled-value="1"
                                     disabled-value="0"
    />

    <form-group-categories namespace="categories"
                           :column-label="$i18n.t('Roles')"
                           :text="$i18n.t('Nodes with the selected roles will be affected. A node without a role (ex: unregistered) is considered to have the default role.')"
    />

    <form-group-oses namespace="oses"
                     :column-label="$i18n.t('OS')"
                     :text="$i18n.t('Nodes with the selected OS will be affected.')"
    />

    <form-group-duration namespace="duration"
                         :column-label="$i18n.t('Duration')"
                         :text="$i18n.t('Approximate duration of a scan. User being scanned on registration are presented a progress bar for this duration, afterwards the browser refreshes until scan is complete.')"
    />

    <form-group-pre-registration namespace="pre_registration"
                                 :column-label="$i18n.t('Scan before registration')"
                                 :text="$i18n.t('If this option is enabled, the PF system will scan host before the registration.')"
                                 enabled-value="1"
                                 disabled-value="0"
    />

    <form-group-registration namespace="registration"
                             :column-label="$i18n.t('Scan on registration')"
                             :text="$i18n.t('If this option is enabled, the PF system will scan each host after registration is complete.')"
                             enabled-value="1"
                             disabled-value="0"
    />

    <form-group-post-registration namespace="post_registration"
                                  :column-label="$i18n.t('Scan after registration')"
                                  :text="$i18n.t('If this option is enabled, the PF system will scan host after on the production VLAN.')"
                                  enabled-value="1"
                                  disabled-value="0"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupCategories,
  FormGroupDuration,
  FormGroupIdentifier,
  FormGroupIp,
  FormGroupOses,
  FormGroupOpenvasAlertIdentifier,
  FormGroupOpenvasConfigIdentifier,
  FormGroupOpenvasDeleteScans,
  FormGroupOpenvasPortListIdentifier,
  FormGroupOpenvasScannerIdentifier,
  FormGroupOpenvasSshPassword,
  FormGroupOpenvasSshUsername,
  FormGroupPassword,
  FormGroupPreRegistration,
  FormGroupPort,
  FormGroupPostRegistration,
  FormGroupRegistration,
  FormGroupUsername
} from './'

const components = {
  BaseForm,

  FormGroupCategories,
  FormGroupDuration,
  FormGroupIdentifier,
  FormGroupIp,
  FormGroupOses,
  FormGroupOpenvasAlertIdentifier,
  FormGroupOpenvasConfigIdentifier,
  FormGroupOpenvasDeleteScans,
  FormGroupOpenvasPortListIdentifier,
  FormGroupOpenvasScannerIdentifier,
  FormGroupOpenvasSshPassword,
  FormGroupOpenvasSshUsername,
  FormGroupPassword,
  FormGroupPreRegistration,
  FormGroupPort,
  FormGroupPostRegistration,
  FormGroupRegistration,
  FormGroupUsername
}

import {useForm as setup, useFormProps as props} from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-openvas',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
