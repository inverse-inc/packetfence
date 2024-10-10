<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
                           :column-label="$i18n.t('Name')"
                           :disabled="!isNew && !isClone"
    />

    <form-group-description namespace="description"
                            :column-label="$i18n.t('Description')"
    />

    <form-group-sources namespace="sources"
                        :column-label="$i18n.t('Associated Sources')"
                        :text="$i18n.t('Sources that will be associated with this source (For the Sponsor).\nOnly sources able to find an email address can be selected.')"
    />

    <form-group-banned-domains namespace="banned_domains"
                               :column-label="$i18n.t('Banned Domains')"
                               :text="$i18n.t('Domains that are banned for email registration. Wildcards are accepted (*pfdemo.org). Banned domains are checked before allowed domains.')"
    />

    <form-group-allowed-domains namespace="allowed_domains"
                                :column-label="$i18n.t('Allowed Domains')"
                                :text="$i18n.t('Domains that are allowed for email registration. Wildcards are accepted (*pfdemo.org). Allowed domains are checked after banned domains.')"
    />

    <form-group-email-activation-timeout namespace="email_activation_timeout"
                                         :column-label="$i18n.t('Email Activation Timeout')"
                                         :text="$i18n.t('This is the delay given to the sponsor to log into his email and click the activation link.')"
    />

    <form-group-allow-localdomain namespace="allow_localdomain"
                                  :column-label="$i18n.t('Allow Local Domain')"
                                  :text="$i18n.t('Accept self-registration with email address from the local domain.')"
                                  enabled-value="yes"
                                  disabled-value="no"
    />

    <form-group-activation-domain namespace="activation_domain"
                                  :column-label="$i18n.t('Host in activation link')"
                                  :text="$i18n.t('Set this value if you want to change the hostname in the validation link. Changing this requires to restart haproxy to be fully effective.')"
    />

    <form-group-sponsorship-bcc namespace="sponsorship_bcc"
                                :column-label="$i18n.t('Sponsorship BCC')"
                                :text="$i18n.t(`Sponsors requesting access and access confirmation emails are BCC'ed to this address. Multiple destinations can be comma-separated.`)"
    />

    <form-group-register-on-activation namespace="register_on_activation"
                                       :column-label="$i18n.t('Register on activation')"
                                       :text="$i18n.t('Whether or not to register the user when the sponsor enables the access. When this is disabled, it requires the user to stay on the portal while it waits for the sponsor to enable the access in order to be able to chain this authentication with other portal modules.')"
                                       enabled-value="enabled"
                                       disabled-value="disabled"
    />

    <form-group-validate-sponsor namespace="validate_sponsor"
                                 :column-label="$i18n.t('Sponsor Validation')"
                                 :text="$i18n.t('Force sponsor to authenticate when validating a guest request.')"
                                 enabled-value="yes"
                                 disabled-value="no"
    />

    <form-group-lang namespace="lang"
                     :column-label="$i18n.t('Language')"
                     :text="$i18n.t('Language for sponsor email.')"
    />

    <form-group-create-local-account namespace="create_local_account"
                                     :column-label="$i18n.t('Create Local Account')"
                                     :text="$i18n.t('Create a local account on the PacketFence system based on the username provided.')"
                                     enabled-value="yes"
                                     disabled-value="no"
    />

    <form-group-hash-passwords namespace="hash_passwords"
                               :column-label="$i18n.t('Database passwords hashing method')"
                               :text="$i18n.t('The algorithm used to hash the passwords in the database.This will only affect newly created or reset passwords.')"
    />

    <form-group-password-length namespace="password_length"
                                :column-label="$i18n.t('Password length')"
                                :text="$i18n.t('The length of the password to generate.')"
    />

    <form-group-local-account-logins namespace="local_account_logins"
                                     :column-label="$i18n.t('Amount of logins for the local account')"
                                     :text="$i18n.t('The amount of times, the local account can be used after its created. 0 means infinite.')"
    />

    <form-group-local-account-expiration namespace="local_account_expiration"
                                         :column-label="$i18n.t('Local account expiration')"
                                         :text="$i18n.t('The amount of time after which the local account will expire. A value of 0 will use the access duration that is found via the authentication rules for the user.')"
    />

    <form-group-authentication-rules namespace="authentication_rules"
                                     :column-label="$i18n.t('Authentication Rules')"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupActivationDomain,
  FormGroupAllowedDomains,
  FormGroupAllowLocaldomain,
  FormGroupAuthenticationRules,
  FormGroupBannedDomains,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupEmailActivationTimeout,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLang,
  FormGroupLocalAccountExpiration,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupRegisterOnActivation,
  FormGroupSources,
  FormGroupSponsorshipBcc,
  FormGroupValidateSponsor
} from './'

const components = {
  BaseForm,

  FormGroupActivationDomain,
  FormGroupAllowedDomains,
  FormGroupAllowLocaldomain,
  FormGroupAuthenticationRules,
  FormGroupBannedDomains,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupEmailActivationTimeout,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLang,
  FormGroupLocalAccountExpiration,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupRegisterOnActivation,
  FormGroupSources,
  FormGroupSponsorshipBcc,
  FormGroupValidateSponsor
}

import {useForm as setup, useFormProps as props} from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-sponsor-email',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
