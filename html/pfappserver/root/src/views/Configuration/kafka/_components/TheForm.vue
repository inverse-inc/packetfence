<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-admin-user namespace="admin.user"
                           :column-label="$i18n.t('Admin Username')"
    />

    <form-group-admin-pass namespace="admin.pass"
                           :column-label="$i18n.t('Admin Password')"
    />

    <form-group-auths namespace="auths"
                      :column-label="$i18n.t('Auth Configuration')"
    />

    <form-group-cluster-config namespace="cluster"
                               :column-label="$i18n.t('Cluster Configuration')"
    />

    <form-group-host-configs namespace="host_configs"
                             :column-label="$i18n.t('Host Configuration')"
    />

    <form-group-iptables namespace="iptables.clients"
                         :column-label="$i18n.t('IPtables Clients')"
                         :buton-label="$i18n.t('Add Client IPv4')"
    />

    <form-group-iptables namespace="iptables.cluster_ips"
                         :column-label="$i18n.t('IPtables Cluster')"
                         :buton-label="$i18n.t('Add Cluster IPv4')"
    />

    <hr>
    <h5 class="mb-3">{{ $i18n.t('mTLS') }}</h5>

    <form-group-ssl-enabled namespace="ssl.enabled"
                            :column-label="$i18n.t('Enable mTLS')"
                            :text="$i18n.t('Enable the SSL/mTLS listener for the Kafka broker.')"
    />

    <form-group-ssl-ca namespace="ssl.ca_id"
                       :column-label="$i18n.t('Certificate Authority')"
                       :text="$i18n.t('The pfpki Certificate Authority used to sign the broker certificate.')"
    />

    <form-group-ssl-input namespace="ssl.cn"
                          :column-label="$i18n.t('Common Name')"
                          :text="$i18n.t('The Common Name of the broker certificate.')"
    />

    <form-group-ssl-input namespace="ssl.dns_names"
                          :column-label="$i18n.t('DNS Names')"
                          :text="$i18n.t('Comma-separated DNS Subject Alternative Names.')"
    />

    <form-group-ssl-input namespace="ssl.ip_addresses"
                          :column-label="$i18n.t('IP Addresses')"
                          :text="$i18n.t('Comma-separated IP Subject Alternative Names.')"
    />

    <form-group-ssl-input namespace="ssl.listener"
                          :column-label="$i18n.t('Listener')"
                          :text="$i18n.t('The Kafka listener to secure with mTLS (the external listener on port 9092). Internal listeners are left unchanged.')"
    />

    <form-group-ssl-peer-ca namespace="ssl.peer_ca"
                            :column-label="$i18n.t('Peer CA Certificate')"
                            :text="$i18n.t('PEM of the peer CA certificate used to validate the peer (truststore).')"
    />

    <b-form-group label-cols="3" :label="$i18n.t('Broker Certificate')">
      <button-kafka-generate-cert :form="form" />
      <b-form-text v-t="'Generate (or renew) the broker certificate from the selected CA and write it to disk. Save the form first to persist the CA and the peer certificate.'" />
    </b-form-group>

  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAdminPass,
  FormGroupAdminUser,
  FormGroupClusterConfig,
  FormGroupHostConfigs,
  FormGroupAuths,
  FormGroupIptables,
  FormGroupSslEnabled,
  FormGroupSslCa,
  FormGroupSslInput,
  FormGroupSslPeerCa,
  ButtonKafkaGenerateCert,
} from './'

const components = {
  BaseForm,

  FormGroupAdminPass,
  FormGroupAdminUser,
  FormGroupClusterConfig,
  FormGroupHostConfigs,
  FormGroupAuths,
  FormGroupIptables,
  FormGroupSslEnabled,
  FormGroupSslCa,
  FormGroupSslInput,
  FormGroupSslPeerCa,
  ButtonKafkaGenerateCert,
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

  return {
    schema
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

