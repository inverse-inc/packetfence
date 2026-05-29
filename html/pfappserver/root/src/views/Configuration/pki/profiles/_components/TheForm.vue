<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>
        <form-group-identifier v-if="!isNew && !isClone"
                               namespace="id"
                               :column-label="$i18n.t('Identifier')"
                               :disabled="!isNew && !isClone"
        />
        <form-group-ca-id namespace="ca_id"
                          :column-label="$i18n.t('Certificate Authority')"
                          :disabled="!isNew && !isClone"
        />
        <form-group-name namespace="name"
                         :column-label="$i18n.t('Name')"
                         :text="$i18n.t('Profile Name.')"
        />
        <form-group-mail namespace="mail"
                         :column-label="$i18n.t('Email')"
                         :text="$i18n.t('Email address of the user. The email with the certificate will be sent to this address.')"
        />
        <form-group-organisational-unit namespace="organisational_unit"
                                        :column-label="$i18n.t('Organisational Unit')"
        />
        <form-group-organisation namespace="organisation"
                                 :column-label="$i18n.t('Organisation')"
        />
        <form-group-country namespace="country"
                            :column-label="$i18n.t('Country')"
        />
        <form-group-state namespace="state"
                          :column-label="$i18n.t('State or Province')"
        />
        <form-group-locality namespace="locality"
                             :column-label="$i18n.t('Locality')"
        />
        <form-group-street-address namespace="street_address"
                                   :column-label="$i18n.t('Street Address')"
        />
        <!-- temporarily hidden
        <form-group-postal-code namespace="postal_code"
          :column-label="$i18n.t('Postal Code')"
        />
        -->
        <form-group-validity namespace="validity"
                             :column-label="$i18n.t('Validity')"
                             :text="$i18n.t('Number of days the certificate will be valid. (value greater than 380 wont work on some devices)')"
        />
        <form-group-key-type namespace="key_type"
                             :column-label="$i18n.t('Key type')"
        />
        <form-group-key-size namespace="key_size"
                             :column-label="$i18n.t('Key size')"
                             :options="keySizeOptions"
        />
        <form-group-digest namespace="digest"
                           :column-label="$i18n.t('Digest')"
        />
        <form-group-key-usage namespace="key_usage"
                              :column-label="$i18n.t('Key usage')"
                              :text="$i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.')"
        />
        <form-group-extended-key-usage namespace="extended_key_usage"
                                       :column-label="$i18n.t('Extended key usage')"
                                       :text="$i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.')"
        />
        <form-group-ocsp-url namespace="ocsp_url"
                             :column-label="$i18n.t('OCSP URL')"
                             :text="$i18n.t('Optional.URL of the OCSP server that will be added in the certificate. If empty then the CA is used')"
        />
        <form-group-allow-duplicated-cn namespace="allow_duplicated_cn"
                                        :column-label="$i18n.t('Allow multiple certificates with same Common Name')"
                                        :text="$i18n.t(`Optional. Allow this profile to create multiple certificates with the same Common Name. Enabling will disable the 'Days before renewal'.`)"
                                        :enabled-value="1"
                                        :disabled-value="0"
        />
        <form-group-maximum-duplicated-cn namespace="maximum_duplicated_cn"
                                         :column-label="$i18n.t('Maximum number of certificates with same Common Name.')"
                                         :text="$i18n.t('Determine the maximum number of certificates the PKI can generate with the same Common Name. Use 0 for unlimited. Expired certs are automatically revoked.')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('PKCS 12')">
        <form-group-p12-mail-password namespace="p12_mail_password"
                                      :column-label="$i18n.t('P12 mail password')"
                                      :text="$i18n.t('Email the password of the pkcs12 file.')"
                                      enabled-value="1"
                                      disabled-value="0"
        />
        <form-group-p12-mail-subject namespace="p12_mail_subject"
                                     :column-label="$i18n.t('P12 mail subject')"
                                     :text="$i18n.t('Email subject.')"
        />
        <form-group-p12-mail-from namespace="p12_mail_from"
                                  :column-label="$i18n.t('P12 mail from')"
                                  :text="$i18n.t('Sender email address.')"
        />
        <form-group-p12-mail-header namespace="p12_mail_header"
                                    :column-label="$i18n.t('P12 mail header')"
                                    :text="$i18n.t('Email header.')"
                                    auto-fit
        />
        <form-group-p12-mail-footer namespace="p12_mail_footer"
                                    :column-label="$i18n.t('P12 mail footer')"
                                    :text="$i18n.t('Email footer.')"
                                    auto-fit
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('SCEP')">
        <form-group-scep-enabled namespace="scep_enabled"
                                 :column-label="$i18n.t('Enable SCEP')"
                                 :text="$i18n.t('Enable SCEP for this template.')"
                                 :enabled-value="1"
                                 :disabled-value="0"
        />
        <form-group-scep-challenge-password namespace="scep_challenge_password"
                                            :column-label="$i18n.t('SCEP challenge password')"
                                            :text="$i18n.t('SCEP challenge password.')"
        />
        <form-group-scep-days-before-renewal namespace="scep_days_before_renewal"
                                             :column-label="$i18n.t('SCEP days before renewal')"
                                             :text="$i18n.t('Number of days before SCEP authorize renewal')"
        />
        <form-group-cloud-enabled namespace="cloud_enabled"
                                  :column-label="$i18n.t('Enable Cloud Integration')"
                                  :text="$i18n.t('Enable Cloud integration for this template.')"
                                  :enabled-value="1"
                                  :disabled-value="0"
        />
        <form-group-cloud-service namespace="cloud_service"
                                  :column-label="$i18n.t('Cloud Service')"
                                  :text="$i18n.t('Cloud Service to integrate.')"
        />
        <form-group-scep-server-enabled namespace="scep_server_enabled"
                                        :column-label="$i18n.t('SCEP Server Enabled')"
                                        :enabled-value="1"
                                        :disabled-value="0"
        />
        <form-group-scep-server-id namespace="scep_server_id"
                                  :column-label="$i18n.t('SCEP Server')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('ACME')">
        <form-group-acme-enabled namespace="acme_enabled"
                                 :column-label="$i18n.t('Enable ACME')"
                                 :text="$i18n.t('Enable RFC 8555 ACME enrollment under this profile. Devices contact /acme/&lt;profile&gt;/directory; everything else is link-discovered. Apple managed-device payloads use this.')"
                                 :enabled-value="1"
                                 :disabled-value="0"
        />
        <form-group-acme-allowed-identifiers namespace="acme_allowed_identifiers"
                                             :column-label="$i18n.t('Allowed identifier types')"
                                             :text="$i18n.t('Comma-separated identifier types accepted in /new-order. dns,ip,email for generic clients; permanent-identifier for Apple managed-device enrollment.')"
        />
        <form-group-acme-eab-required namespace="acme_eab_required"
                                      :column-label="$i18n.t('Require External Account Binding')"
                                      :text="$i18n.t('When enabled, /new-account must carry a valid EAB inner JWS. Mint keys in the EAB tab and distribute via MDM payload.')"
                                      :enabled-value="1"
                                      :disabled-value="0"
        />
        <form-group-acme-attestation-formats namespace="acme_attestation_formats"
                                             :column-label="$i18n.t('Attestation formats')"
                                             :text="$i18n.t('Comma-separated attestation formats accepted on device-attest-01. Only apple is implemented today; leaving empty disables device-attest-01 and falls back to http-01.')"
        />
        <form-group-acme-attestation-roots namespace="acme_attestation_roots"
                                           :column-label="$i18n.t('Attestation root CAs (PEM)')"
                                           :text="$i18n.t('Optional PEM bundle of trusted attestation roots. Overrides the embedded Apple Enterprise Attestation Root CA. Leave empty to use the built-in roots.')"
                                           auto-fit
        />
        <form-group-acme-account-expiry namespace="acme_account_expiry"
                                        :column-label="$i18n.t('Account expiry (days)')"
                                        :text="$i18n.t('How long an ACME account lives before the state cleanup task is allowed to drop it.')"
        />
        <form-group-acme-order-expiry namespace="acme_order_expiry"
                                      :column-label="$i18n.t('Order expiry (days)')"
                                      :text="$i18n.t('Lifetime of a new-order before it is considered expired and reclaimed by the cleanup task.')"
        />
        <form-group-acme-authz-expiry namespace="acme_authz_expiry"
                                      :column-label="$i18n.t('Authorization expiry (hours)')"
                                      :text="$i18n.t('Lifetime of an authorization (and its challenges) before reclamation. ACME clients refresh this from the directory.')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Renewal Configuration')">
        <form-group-days-before-renewal namespace="days_before_renewal"
                                        :column-label="$i18n.t('Days before renewal')"
                                        :text="$i18n.t('Number of days before the PKI authorizes renewal. Setting it to 0 means renewal is always allowed.')"
        />
        <form-group-renewal-mail namespace="renewal_mail"
                                 :column-label="$i18n.t('Renewal Email')"
                                 :text="$i18n.t('Send an email to the owner of the certificate when it is about to expire.')"
                                 :enabled-value="1"
                                 :disabled-value="0"
        />
        <form-group-days-before-renewal-mail namespace="days_before_renewal_mail"
                                             :column-label="$i18n.t('Days before sending renewal email')"
                                             :text="$i18n.t('Number of days before certificate expiration to trigger sending email. Ignored when the schedule below is set.')"
        />
        <form-group-renewal-mail-days namespace="renewal_mail_days"
                                      :column-label="$i18n.t('Renewal email schedule')"
                                      :text="$i18n.t('Optional comma-separated thresholds in days before expiry, e.g. \'14,7,1\'. When set, the certificate owner is emailed once per threshold instead of repeatedly once the single value above is crossed.')"
        />
        <form-group-renewal-mail-subject namespace="renewal_mail_subject"
                                         :column-label="$i18n.t('Renewal mail subject')"
                                         :text="$i18n.t('Subject of the renewal email.')"
        />
        <form-group-renewal-mail-from namespace="renewal_mail_from"
                                      :column-label="$i18n.t('Renewal mail from')"
                                      :text="$i18n.t('Sender address of the renewal email.')"
        />
        <form-group-renewal-mail-header namespace="renewal_mail_header"
                                        :column-label="$i18n.t('Renewal mail header')"
                                        :text="$i18n.t('Renewal email header.')"
                                        auto-fit
        />
        <form-group-renewal-mail-footer namespace="renewal_mail_footer"
                                        :column-label="$i18n.t('Renewal mail footer')"
                                        :text="$i18n.t('Renewal email footer.')"
                                        auto-fit
        />
        <form-group-revoked-valid-until namespace="revoked_valid_until"
                                        :column-label="$i18n.t('Days after revoked certificate is valid')"
                                        :text="$i18n.t('Number of days an old certificate is still valid after it has been revoked.')"
        />
      </base-form-tab>

      <template #tabs-end v-if="!isNew && !isClone">
        <div class="text-right mr-3 mb-1">
          <b-button
            size="sm" variant="outline-primary" class="mr-1 text-nowrap"
            :disabled="!isServiceAlive" :to="{ name: 'newPkiCert', params: { profile_id: id } }"
          >{{ $t('New Certificate') }}
          </b-button>
          <b-button
            size="sm" variant="outline-primary" class="text-nowrap"
            :disabled="!isServiceAlive" :to="{ name: 'csrPkiProfile', params: { id } }"
          >{{ $i18n.t('Sign CSR') }}
          </b-button>
        </div>
      </template>
    </b-tabs>
  </base-form>
</template>
<script>
import {BaseForm, BaseFormTab} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAllowDuplicatedCn,
  FormGroupCaId,
  FormGroupCloudEnabled,
  FormGroupCloudService,
  FormGroupCountry,
  FormGroupDaysBeforeRenewal,
  FormGroupDaysBeforeRenewalMail,
  FormGroupRenewalMailDays,
  FormGroupDigest,
  FormGroupExtendedKeyUsage,
  FormGroupIdentifier,
  FormGroupKeySize,
  FormGroupKeyType,
  FormGroupKeyUsage,
  FormGroupLocality,
  FormGroupMail,
  FormGroupMaximumDuplicatedCn,
  FormGroupName,
  FormGroupOcspUrl,
  FormGroupOrganisation,
  FormGroupOrganisationalUnit,
  FormGroupP12MailFooter,
  FormGroupP12MailFrom,
  FormGroupP12MailHeader,
  FormGroupP12MailPassword,
  FormGroupP12MailSubject,
  FormGroupRenewalMail,
  FormGroupRenewalMailFooter,
  FormGroupRenewalMailFrom,
  FormGroupRenewalMailHeader,
  FormGroupRenewalMailSubject,
  FormGroupRevokedValidUntil,
  FormGroupScepChallengePassword,
  FormGroupScepDaysBeforeRenewal,
  FormGroupScepEnabled,
  FormGroupState,
  FormGroupStreetAddress,
  FormGroupValidity,
  FormGroupScepServerEnabled,
  FormGroupScepServerId,
  FormGroupAcmeEnabled,
  FormGroupAcmeAllowedIdentifiers,
  FormGroupAcmeEabRequired,
  FormGroupAcmeAttestationFormats,
  FormGroupAcmeAttestationRoots,
  FormGroupAcmeAccountExpiry,
  FormGroupAcmeOrderExpiry,
  FormGroupAcmeAuthzExpiry
} from './'
import {computed, toRefs} from '@vue/composition-api'
import {keySizes, keyTypes} from '../../config'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupAllowDuplicatedCn,
  FormGroupCaId,
  FormGroupName,
  FormGroupMail,
  FormGroupOrganisationalUnit,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  // FormGroupPostalCode,
  FormGroupValidity,
  FormGroupKeyType,
  FormGroupKeySize,
  FormGroupDigest,
  FormGroupKeyUsage,
  FormGroupExtendedKeyUsage,
  FormGroupMaximumDuplicatedCn,
  FormGroupOcspUrl,
  FormGroupP12MailPassword,
  FormGroupP12MailSubject,
  FormGroupP12MailFrom,
  FormGroupP12MailHeader,
  FormGroupP12MailFooter,
  FormGroupScepEnabled,
  FormGroupScepChallengePassword,
  FormGroupScepDaysBeforeRenewal,
  FormGroupCloudEnabled,
  FormGroupCloudService,
  FormGroupDaysBeforeRenewal,
  FormGroupRenewalMail,
  FormGroupDaysBeforeRenewalMail,
  FormGroupRenewalMailDays,
  FormGroupRenewalMailSubject,
  FormGroupRenewalMailFrom,
  FormGroupRenewalMailHeader,
  FormGroupRenewalMailFooter,
  FormGroupRevokedValidUntil,
  FormGroupScepServerEnabled,
  FormGroupScepServerId,
  FormGroupAcmeEnabled,
  FormGroupAcmeAllowedIdentifiers,
  FormGroupAcmeEabRequired,
  FormGroupAcmeAttestationFormats,
  FormGroupAcmeAttestationRoots,
  FormGroupAcmeAccountExpiry,
  FormGroupAcmeOrderExpiry,
  FormGroupAcmeAuthzExpiry
}

export const props = {
  id: {
    type: String
  },
  ca_id: {
    type: String
  },
  form: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props, context) => {

  const {
    form
  } = toRefs(props)

  const {root: {$store} = {}} = context

  const schema = computed(() => schemaFn(props))

  const keySizeOptions = computed(() => {
    const {key_type} = form.value || {}
    if (key_type) {
      const {[+key_type]: {sizes = []} = {}} = keyTypes
      return sizes.map(size => ({text: `${size}`, value: `${size}`}))
    }
    return keySizes
  })

  const isServiceAlive = computed(() => {
    const {pfpki: {hasAlive = false} = {}} = $store.getters['cluster/servicesByServer']
    return hasAlive
  })

  return {
    schema,
    keySizeOptions,
    isServiceAlive
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

