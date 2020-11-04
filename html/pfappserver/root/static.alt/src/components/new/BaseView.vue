<template>
  <b-card no-body>
    <b-card-header>
      <slot name="header"/>
    </b-card-header>
    <slot name="default" class="card-body"/>
    <b-card-footer>
      <slot name="footer"/>
    </b-card-footer>
  </b-card>
</template>
<script>
// @vue/component
export default {
  name: 'base-view',
  inheritAttrs: false
}
</script>
