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

    <form-group-broker-only-hosts namespace="general.broker_only_hosts"
                                  :column-label="$i18n.t('Broker Only Servers')"
                                  :text="$i18n.t('Servers of the cluster that run Kafka without being part of the controller quorum (e.g. the servers of a secondary zone). Run /usr/local/pf/bin/kafka-init.pl to apply: the controller quorum is fixed when the Kafka cluster is created, changing it requires to remove the Kafka data of every server.')"
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

  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAdminPass,
  FormGroupAdminUser,
  FormGroupBrokerOnlyHosts,
  FormGroupClusterConfig,
  FormGroupHostConfigs,
  FormGroupAuths,
  FormGroupIptables,
} from './'

const components = {
  BaseForm,

  FormGroupAdminPass,
  FormGroupAdminUser,
  FormGroupBrokerOnlyHosts,
  FormGroupClusterConfig,
  FormGroupHostConfigs,
  FormGroupAuths,
  FormGroupIptables,
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

