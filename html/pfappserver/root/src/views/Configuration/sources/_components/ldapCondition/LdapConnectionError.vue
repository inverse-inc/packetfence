<template>
  <b-media class="text-secondary" md="auto">
    <template #aside>
      <icon name="exclamation-triangle" scale="1.5" class="mt-2 ml-2"></icon>
    </template>
    <strong>{{ $t('LDAP connection failed') }}</strong>
    <b-form-text class="font-weight-light">
      {{ $t('Make sure that you provided correct IP/credentials') }}
    </b-form-text>
  </b-media>
</template>
<script>
export default {
  name: 'ldap-connection-error',
}
</script>
