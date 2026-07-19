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

    <form-group-method :column-label="$i18n.t('Method')"
                       :text="$i18n.t('The HTTP method of the request.')"
                       namespace="method"
    />

    <form-group-url :column-label="$i18n.t('URL')"
                    :text="$i18n.t('The URL of the request. This is a template: $mac is the MAC address of the device and $node.attribute (ex: $node.pid, $node.category) are the attributes of the node.')"
                    namespace="url"
    />

    <form-group-headers :column-label="$i18n.t('Headers')"
                        :text="$i18n.t('The headers of the request, one \'Name: value\' per line. Names and values are templates like the URL.')"
                        namespace="headers"
    />

    <form-group-body :column-label="$i18n.t('Body')"
                     :text="$i18n.t('The body of the request, sent for POST, PUT and PATCH requests. This is a template like the URL.')"
                     namespace="body"
    />

    <form-group-content-type :column-label="$i18n.t('Content-Type')"
                             :text="$i18n.t('The Content-Type of the request body. Ignored when a Content-Type header is defined in the headers.')"
                             namespace="content_type"
    />

    <form-group-timeout :column-label="$i18n.t('Timeout')"
                        :text="$i18n.t('Timeout in seconds of the request.')"
                        namespace="timeout"
    />

    <form-group-username :column-label="$i18n.t('Username')"
                         :text="$i18n.t('Optional username for HTTP basic authentication.')"
                         namespace="username"
    />

    <form-group-password :column-label="$i18n.t('Password')"
                         :text="$i18n.t('Optional password for HTTP basic authentication.')"
                         namespace="password"
    />

    <form-group-verify-ssl :column-label="$i18n.t('Verify TLS')"
                           :text="$i18n.t('Whether or not the TLS certificate of the server is verified.')"
                           disabled-value="disabled"
                           enabled-value="enabled"
                           namespace="verify_ssl"
    />

    <form-group-client-cert-file :column-label="$i18n.t('Client certificate')"
                                 :text="$i18n.t('The client TLS certificate used to authenticate against the server.')"
                                 :title="$i18n.t('Upload client certificate')"
                                 namespace="client_cert_file"
    />

    <form-group-client-key-file :column-label="$i18n.t('Client key')"
                                :text="$i18n.t('The private key of the client TLS certificate.')"
                                :title="$i18n.t('Upload client key')"
                                namespace="client_key_file"
    />

    <form-group-ca-file :column-label="$i18n.t('CA certificate')"
                        :text="$i18n.t('The CA certificate used to verify the server certificate.')"
                        :title="$i18n.t('Upload CA certificate')"
                        namespace="ca_file"
    />

    <form-group-jq-query :column-label="$i18n.t('JQ query')"
                         :text="$i18n.t('The jq query applied to the JSON response. The device is authorized when the query returns a truthy value: every result that is not null or false passes, an empty result fails.')"
                         namespace="jq_query"
    />

    <form-group-jq-test :column-label="$i18n.t('Test JQ query')"
                        :text="$i18n.t('Paste a sample JSON response here and click Test to evaluate the JQ query above against it.')"
                        namespace="test_json"
    />

  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBody,
  FormGroupCaFile,
  FormGroupCategory,
  FormGroupClientCertFile,
  FormGroupClientKeyFile,
  FormGroupContentType,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHeaders,
  FormGroupIdentifier,
  FormGroupJqQuery,
  FormGroupJqTest,
  FormGroupMethod,
  FormGroupOses,
  FormGroupPassword,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupTimeout,
  FormGroupUrl,
  FormGroupUsername,
  FormGroupVerifySsl,
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupBody,
  FormGroupCaFile,
  FormGroupCategory,
  FormGroupClientCertFile,
  FormGroupClientKeyFile,
  FormGroupContentType,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHeaders,
  FormGroupIdentifier,
  FormGroupJqQuery,
  FormGroupJqTest,
  FormGroupMethod,
  FormGroupOses,
  FormGroupPassword,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupTimeout,
  FormGroupUrl,
  FormGroupUsername,
  FormGroupVerifySsl,
}

// @vue/component
export default {
  name: 'form-type-generic-http',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
