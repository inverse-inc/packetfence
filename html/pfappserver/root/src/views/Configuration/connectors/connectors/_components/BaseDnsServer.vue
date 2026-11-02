<template>
  <div class="w-100">
    <!-- align-v="start": an error under one input must not re-center the others -->
    <b-row align-v="start" no-gutters>
      <b-col cols="3" class="pr-2">
        <label class="base-dns-server-label">{{ $t('DNS server IP') }}</label>
        <base-input
          :namespace="`${namespace}.ip`"
          :placeholder="$t('e.g. 10.5.1.53')"
        />
      </b-col>
      <b-col cols="2" class="pr-2">
        <label class="base-dns-server-label">{{ $t('Port') }}</label>
        <base-input-number
          :namespace="`${namespace}.port`"
          placeholder="53"
          :min="1"
          :max="65535"
        />
      </b-col>
      <b-col cols="5" class="pr-2">
        <label class="base-dns-server-label">{{ $t('Domains served') }}</label>
        <base-input-chosen-multiple
          :namespace="`${namespace}.domains`"
          :placeholder="$t('Type a domain name and press enter (e.g. inverse.local)')"
          :taggable="true"
          :tag-placeholder="$t('Add this domain')"
          :options="[]"
        />
      </b-col>
      <b-col cols="2">
        <label class="base-dns-server-label">{{ $t('Tunnel port') }}</label>
        <base-input-number
          :namespace="`${namespace}.tunnel_port`"
          :placeholder="$t('automatic')"
          :min="30000"
          :max="30999"
        />
      </b-col>
    </b-row>
  </div>
</template>
<script>
import {
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputNumber
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputNumber
}

import { useInputMetaProps } from '@/composables/useMeta'
import { useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

// @vue/component
export default {
  name: 'base-dns-server',
  inheritAttrs: false,
  components,
  props
}
</script>
<style lang="scss">
.base-dns-server-label {
  display: block;
  margin-bottom: 0.125rem;
  font-size: $font-size-sm;
  color: $text-muted;
}
</style>
