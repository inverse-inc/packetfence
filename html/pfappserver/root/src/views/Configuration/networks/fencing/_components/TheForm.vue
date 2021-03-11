<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-wait-for-redirect namespace="wait_for_redirect"
      :column-label="$i18n.t('Wait for redirect')"
      :text="$i18n.t(`How many seconds the webservice should wait before deassociating or reassigning VLAN. If we don't wait, the device may switch VLAN before it has a chance to load the redirection page.`)"
    />

    <form-group-whitelist namespace="whitelist"
      :column-label="$i18n.t('Whitelist')"
      :text="$i18n.t('Comma-separated list of MAC addresses that are immune to isolation. In inline Level 2 enforcement, the firewall is opened for them as if they were registered. This feature will probably be reworked in the future.')"
    />

    <form-group-range namespace="range"
      :column-label="$i18n.t('Addresses ranges')"
      :text="$i18n.t('Address ranges/CIDR blocks that PacketFence will monitor/detect/trap on. Gateway, network, and broadcast addresses are ignored. Comma-separated entries should be of the form\na.b.c.0/24\na.b.c.0-255\na.b.c.0-a.b.c.255\na.b.c.d')"
    />

    <form-group-passthrough namespace="passthrough"
      :column-label="$i18n.t('Passthrough')"
      :text="$i18n.t('When enabled, PacketFence uses pfdns if you defined Passthroughs or Apache mod-proxy if you defined Proxy passthroughs to allow trapped devices to reach web sites. Modifying this parameter requires to restart pfdns and iptables to be fully effective.')"
    />

    <form-group-passthroughs namespace="passthroughs"
      :column-label="$i18n.t('Passthroughs Domains')"
      :text="$i18n.t('Comma-separated list of domains to allow access from the registration VLAN.If no port is specified for the domain (ex: example.com), it opens TCP 80 and 443. You can specify a specific port to open (ex: example.com:tcp:25) which opens port 25 in TCP. When no protocol is specified (ex: example.com:25), this opens the port for both the UDP and TCP protocol. You can specify the same domain with a different port multiple times and they will be combined. The configuration parameter passthrough must be enabled for passthroughs to be effective. These passthroughs are only effective in registration networks, for passthroughs in isolation, use fencing.isolation_passthroughs.')"
    />

    <form-group-proxy-passthroughs namespace="proxy_passthroughs"
      :column-label="$i18n.t('Proxy Passthroughs')"
      :text="$i18n.t('Comma-separated list of domains to be used with apache passthroughs. The configuration parameter passthrough must be enabled for passthroughs to be effective.')"
    />
    <b-row>
      <b-col cols="3"></b-col>
      <b-col cols="9">
        <div class="alert alert-info mr-3">
          <p><strong>{{ $i18n.t('Built-in Proxy Passthroughs:') }}</strong></p>
          <span v-for="passthrough in passthroughsBuiltIn" :key="passthrough"
            class="badge badge-info mr-1">{{ passthrough }}</span>
        </div>
      </b-col>
    </b-row>

    <form-group-isolation-passthrough namespace="isolation_passthrough"
      :column-label="$i18n.t('Isolation Passthrough')"
      :text="$i18n.t('When enabled, PacketFence uses pfdns if you defined Isolation Passthroughs to allow trapped devices in isolation state to reach web sites. Modifying this parameter requires to restart pfdns and iptables to be fully effective.')"
    />

    <form-group-isolation-passthroughs namespace="isolation_passthroughs"
      :column-label="$i18n.t('Isolation Passthroughs Domains')"
      :text="$i18n.t('Comma-separated list of domains to allow access from the isolation VLAN. If no port is specified for the domain (ex: example.com), it opens TCP 80 and 443.You can specify a specific port to open (ex: example.com:tcp:25) which opens port 25 in TCP. When no protocol is specified (ex: example.com:25), this opens the port for both the UDP and TCP protocol. You can specify the same domain with a different port multiple times and they will be combined. The configuration parameter isolation_passthrough must be enabled for passthroughs to be effective.')"
    />

    <form-group-interception-proxy namespace="interception_proxy"
      :column-label="$i18n.t('Proxy Interception')"
      :text="$i18n.t('If enabled, we will intercept proxy request on the specified ports to forward to the captive portal.')"
    />

    <form-group-interception-proxy-port namespace="interception_proxy_port"
      :column-label="$i18n.t('Proxy Interception Port')"
      :text="$i18n.t('Comma-separated list of port used by proxy interception.')"
    />
  </base-form>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import {
  FormGroupWaitForRedirect,
  FormGroupWhitelist,
  FormGroupRange,
  FormGroupPassthrough,
  FormGroupPassthroughs,
  FormGroupProxyPassthroughs,
  FormGroupIsolationPassthrough,
  FormGroupIsolationPassthroughs,
  FormGroupInterceptionProxy,
  FormGroupInterceptionProxyPort
} from './'

const components = {
  BaseForm,

  FormGroupWaitForRedirect,
  FormGroupWhitelist,
  FormGroupRange,
  FormGroupPassthrough,
  FormGroupPassthroughs,
  FormGroupProxyPassthroughs,
  FormGroupIsolationPassthrough,
  FormGroupIsolationPassthroughs,
  FormGroupInterceptionProxy,
  FormGroupInterceptionProxyPort
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

import { useNamespaceMetaPlaceholder } from '@/composables/useMeta'
import schemaFn from '../schema'

export const setup = (props) => {

  const {
    meta
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const passthroughsBuiltIn = computed(() => (useNamespaceMetaPlaceholder('proxy_passthroughs', meta) || '').split(','))

  return {
    schema,
    passthroughsBuiltIn
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

