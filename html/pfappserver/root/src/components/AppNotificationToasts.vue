<template>
  <div class="notifications-toasts">
    <b-alert v-for="(notification) in newNotifications" :key="notification.id" variant="secondary"
      @dismissed="dismiss(notification)" show fade dismissible>
      <b-row class="justify-content-md-center">
        <b-col>
          <div class="notification-message">
            <b-badge pill v-if="notification.value" class="mr-2" :variant="notification.variant">{{notification.value}}</b-badge>
            <icon v-else :name="notification.icon" class="mr-1" :class="'text-'+notification.variant" /> <span v-html="notification.message" />
          </div>
          <small class="notification-url text-secondary">{{notification.url}}</small>
        </b-col>
        <b-col cols="auto" class="text-right">
          <b-badge pill v-if="notification.success" variant="success" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.success + ' ' + $t('succeeded')">{{notification.success}}</b-badge>
          <b-badge pill v-if="notification.skipped" variant="warning" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.skipped + ' ' + $t('skipped')">{{notification.skipped}}</b-badge>
          <b-badge pill v-if="notification.failed" variant="danger" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.failed + ' ' + $t('failed')">{{notification.failed}}</b-badge>
        </b-col>
      </b-row>
    </b-alert>
  </div>
</template>

<script>
import { computed } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const notifications = computed(() => $store.state.notification.all)
  const newNotifications = computed(() => notifications.value.filter(n => n.new))
  const dismiss = notification => $store.commit('notification/NOTIFICATION_DISMISS', notification)

  return {
    newNotifications,
    dismiss
  }
}

// @vue/component
export default {
  name: 'app-notification-toasts',
  setup
}
</script>

<style lang="scss">
$enable-shadows: true;

.notifications-toasts {
    position: fixed;
    z-index: $zindex-tooltip;
    top: .5rem; // in case of a single one-line notification, center the notification in the top navbar
    right: 4rem; // keep the notification bell icon visible in the top navbar
    width: 30vw;

    .alert {
        @include box-shadow($toast-box-shadow);
    }
}
</style>
