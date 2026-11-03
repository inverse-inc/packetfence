<template>
  <b-container>
    <h4>
      <icon class="mr-2" name="flask" scale="1.5" />
      {{ $t('Hello World') }}
    </h4>
    <p v-t="'A configuration section provided by the hello-world UI extension.'" />
  </b-container>
</template>

<script>
// @vue/component
export default {
  name: 'the-section'
}
</script>
