<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('PKI Provider Name')"
      :disabled="!isNew && !isClone"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAccessToken,
  FormGroupAgentDownloadUri,
  FormGroupAltAgentDownloadUri,
  FormGroupAndroidAgentDownloadUri,
  FormGroupAndroidDownloadUri,
  FormGroupApiPassword,
  FormGroupApiUrl,
  FormGroupApiUsername,
  FormGroupApplicationIdentifier,
  FormGroupApplicationSecret,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBoardingHost,
  FormGroupBoardingPort,
  FormGroupBroadcast,
  FormGroupCanSignProfile,
  FormGroupCategory,
  FormGroupCertChain,
  FormGroupCertificate,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupCriticalIssuesThreshold,
  FormGroupDescription,
  FormGroupDeviceTypeDetection,
  FormGroupDomains,
  FormGroupDpsk,
  FormGroupEapType,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupIosAgentDownloadUri,
  FormGroupIosDownloadUri,
  FormGroupLoginUrl,
  FormGroupMacOsxAgentDownloadUri,
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupPasscode,
  FormGroupPassword,
  FormGroupPkiProvider,
  FormGroupPort,
  FormGroupPrivateKey,
  FormGroupProtocol,
  FormGroupPskSize,
  FormGroupQueryComputers,
  FormGroupQueryMobileDevices,
  FormGroupRefreshToken,
  FormGroupRoleToApply,
  FormGroupSecurityType,
  FormGroupServerCertificatePath,
  FormGroupSsid,
  FormGroupSyncPid,
  FormGroupTableForAgent,
  FormGroupTableForMac,
  FormGroupTenantCode,
  FormGroupTenantIdentifier,
  FormGroupUsername,
  FormGroupWindowsAgentDownloadUri,
  FormGroupWindowsPhoneDownloadUri
} from './'

const components = {
  BaseForm,

  FormGroupAccessToken,
  FormGroupAgentDownloadUri,
  FormGroupAltAgentDownloadUri,
  FormGroupAndroidAgentDownloadUri,
  FormGroupAndroidDownloadUri,
  FormGroupApiPassword,
  FormGroupApiUrl,
  FormGroupApiUsername,
  FormGroupApplicationIdentifier,
  FormGroupApplicationSecret,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBoardingHost,
  FormGroupBoardingPort,
  FormGroupBroadcast,
  FormGroupCanSignProfile,
  FormGroupCategory,
  FormGroupCertChain,
  FormGroupCertificate,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupCriticalIssuesThreshold,
  FormGroupDescription,
  FormGroupDeviceTypeDetection,
  FormGroupDomains,
  FormGroupDpsk,
  FormGroupEapType,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupIosAgentDownloadUri,
  FormGroupIosDownloadUri,
  FormGroupLoginUrl,
  FormGroupMacOsxAgentDownloadUri,
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupPasscode,
  FormGroupPassword,
  FormGroupPkiProvider,
  FormGroupPort,
  FormGroupPrivateKey,
  FormGroupProtocol,
  FormGroupPskSize,
  FormGroupQueryComputers,
  FormGroupQueryMobileDevices,
  FormGroupRefreshToken,
  FormGroupRoleToApply,
  FormGroupSecurityType,
  FormGroupServerCertificatePath,
  FormGroupSsid,
  FormGroupSyncPid,
  FormGroupTableForAgent,
  FormGroupTableForMac,
  FormGroupTenantCode,
  FormGroupTenantIdentifier,
  FormGroupUsername,
  FormGroupWindowsAgentDownloadUri,
  FormGroupWindowsPhoneDownloadUri
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-windows',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
