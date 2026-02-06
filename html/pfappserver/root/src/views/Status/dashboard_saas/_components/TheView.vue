<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Dashboard'"></h4>
    </b-card-header>
    <div class="card-body text-center py-5">
      <p class="text-muted mb-4">{{ $t('View metrics and monitoring in Grafana') }}</p>
      <b-button variant="primary" href="/api/v1/grafana/dashboards" target="_blank">
        <icon name="grafana" class="mr-1" /> {{ $t('Open Grafana Dashboard') }}
      </b-button>
    </div>
  </b-card>
</template>

<script>
// @vue/component
export default {
  name: 'the-view'
}
</script>
