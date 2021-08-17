<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-ip-address namespace="ip_address"
      :column-label="$i18n.t('IP address')"
      :text="$i18n.t('The IP address the portal uses in the registration and isolation networks. Do not change unless you know what you are doing. Changing this requires to restart all of the PacketFence services.')"
    />

    <form-group-network-detection namespace="network_detection"
      :column-label="$i18n.t('Network detection')"
      :text="$i18n.t('Enable the automatic network detection feature for registration auto-redirect.')"
    />

    <form-group-network-detection-ip namespace="network_detection_ip"
      :column-label="$i18n.t('Network detection IP')"
      :text="$i18n.t(`This IP is used as the webserver who hosts the common/network-access-detection.gif which is used to detect if network access was enabled. It cannot be a domain name since it is used in registration or quarantine where DNS is blackholed. It is recommended that you allow your users to reach your PacketFence server and put your LAN's PacketFence IP. By default we will make this reach PacketFence's website as an easy solution.`)"
    />

    <form-group-network-detection-initial-delay namespace="network_detection_initial_delay"
      :column-label="$i18n.t('Initial delay')"
      :text="$i18n.t('The amount of time before network connectivity detection is started.')"
    />

    <form-group-network-detection-retry-delay namespace="network_detection_retry_delay"
      :column-label="$i18n.t('Retry delay')"
      :text="$i18n.t('The amount of time between network connectivity detection checks.')"
    />

    <form-group-network-redirect-delay namespace="network_redirect_delay"
      :column-label="$i18n.t('Redirection delay')"
      :text="$i18n.t('How long to display the progress bar during trap release. Default value is based on VLAN enforcement techniques. Inline enforcement only users could lower the value.')"
    />

    <form-group-image-path namespace="image_path"
      :column-label="$i18n.t('Image path')"
      :text="$i18n.t('This is the path where the gif is on the webserver to detect if the network access has been enabled.')"
    />

    <form-group-request-timeout namespace="request_timeout"
      :column-label="$i18n.t('Request timeout')"
      :text="$i18n.t('The amount of seconds before a request times out in the captive portal.')"
    />

    <form-group-loadbalancers-ip namespace="loadbalancers_ip"
      :column-label="$i18n.t('Load balancers IP')"
      :text="$i18n.t('If the captive portal is put behind load-balancer(s) that act at Layer 7 (HTTP level) effectively doing reverse proxying then the captive portal no longer sees the IP of the node trying to access the portal. In that case, the load-balancers must do SSL offloading and add a X-Forwarded-By header in the HTTP traffic they forward to PacketFence. Most do by default. Then in this parameter you must specify the IP of the various load balancers. This will instruct the captive portal to look for client IPs in the X-Forwarded-For instead of the actual TCP session when it matches an IP in the list. Format is a comma separated list of IPs. Note: Apache access log format is not changed to automatically log the X-Forwarded-By header. Modify conf/httpd.conf.d/captive-portal-common.conf to use load balanced combined instead of combined in CustomLog statement.')"
    />

    <form-group-secure-redirect namespace="secure_redirect"
      :column-label="$i18n.t('Secure redirect')"
      :text="$i18n.t('Force the captive portal to use HTTPS for all portal clients.Note that clients will be forced to use HTTPS on all URLs.This requires a restart of the httpd.portal process to be fully effective.')"
    />

    <form-group-status-only-on-production namespace="status_only_on_production"
      :column-label="$i18n.t('Status URI only on production network')"
      :text="$i18n.t('When enabled the /status page will only be available on the production network. By default this is disabled.')"
    />

    <form-group-detection-mecanism-bypass namespace="detection_mecanism_bypass"
      :column-label="$i18n.t('Captive Portal detection mechanism bypass')"
      :text="$i18n.t('Bypass the captive-portal detection mechanism of some browsers / end-points by proxying the detection request.')"
    />

    <form-group-detection-mecanism-urls namespace="detection_mecanism_urls"
      :column-label="$i18n.t('Captive Portal detection mechanism URLs')"
      :text="$i18n.t('Comma-separated list of URLs known to be used by devices to detect the presence of a captive portal and trigger their captive portal mechanism.')"
    />
    <b-row>
      <b-col cols="3"></b-col>
      <b-col cols="9">
        <div class="alert alert-info mr-3">
          <p><strong>{{ $i18n.t('Built-in Captive Portal detection mechanism URLs:') }}</strong></p>
          <span v-for="url in impliedDetectionMechanismUrls" :key="url"
            class="badge badge-info mr-1">{{ url }}</span>
        </div>
      </b-col>
    </b-row>

    <form-group-wispr-redirection namespace="wispr_redirection"
      :column-label="$i18n.t('WISPr redirection capabilities')"
      :text="$i18n.t('Enable or disable WISPr redirection capabilities on the captive-portal.')"
    />

    <form-group-rate-limiting namespace="rate_limiting"
      :column-label="$i18n.t('Rate limiting')"
      :text="$i18n.t('Temporarily deny access to a user that performs too many requests on the captive portal on invalid URLs. Requires to restart haproxy-portal in order to apply the change.')"
    />

    <form-group-rate-limiting-threshold namespace="rate_limiting_threshold"
      :column-label="$i18n.t('Rate limiting threshold')"
      :text="$i18n.t('Amount of requests on invalid URLs after which the rate limiting will kick in for this device. Requires to restart haproxy-portal in order to apply the change.')"
    />

    <form-group-other-domain-names namespace="other_domain_names"
      :column-label="$i18n.t('Other domain name')"
      :text="$i18n.t('Other domain names under which the captive portal responds. Requires to restart haproxy-portal to be fully effective.')"
    />
  </base-form>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIpAddress,
  FormGroupNetworkDetection,
  FormGroupNetworkDetectionIp,
  FormGroupNetworkDetectionInitialDelay,
  FormGroupNetworkDetectionRetryDelay,
  FormGroupNetworkRedirectDelay,
  FormGroupImagePath,
  FormGroupRequestTimeout,
  FormGroupLoadbalancersIp,
  FormGroupSecureRedirect,
  FormGroupStatusOnlyOnProduction,
  FormGroupDetectionMecanismBypass,
  FormGroupDetectionMecanismUrls,
  FormGroupWisprRedirection,
  FormGroupRateLimiting,
  FormGroupRateLimitingThreshold,
  FormGroupOtherDomainNames
} from './'

const components = {
  BaseForm,

  FormGroupIpAddress,
  FormGroupNetworkDetection,
  FormGroupNetworkDetectionIp,
  FormGroupNetworkDetectionInitialDelay,
  FormGroupNetworkDetectionRetryDelay,
  FormGroupNetworkRedirectDelay,
  FormGroupImagePath,
  FormGroupRequestTimeout,
  FormGroupLoadbalancersIp,
  FormGroupSecureRedirect,
  FormGroupStatusOnlyOnProduction,
  FormGroupDetectionMecanismBypass,
  FormGroupDetectionMecanismUrls,
  FormGroupWisprRedirection,
  FormGroupRateLimiting,
  FormGroupRateLimitingThreshold,
  FormGroupOtherDomainNames
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

import { useNamespaceMetaImplied } from '@/composables/useMeta'

export const setup = (props) => {

  const {
    meta
  } = toRefs(props)

  const impliedDetectionMechanismUrls = computed(() => (useNamespaceMetaImplied('detection_mecanism_urls', meta) || '').split(','))

  const schema = computed(() => schemaFn(props))

  return {
    schema,
    impliedDetectionMechanismUrls
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

