<template>
  <div class="notifications">
    <b-nav-item-dropdown @click.native.stop.prevent right :disabled="isEmpty">
      <template slot="button-content">
        <icon name="bell"></icon>
      </template>
      <b-dropdown-item class="border-right" v-for="(notification, index) in notifications" :key="index" :class="'border-'+notification.variant">
        <small>
          <timeago class="float-right" :class="{'text-secondary': !notification.new}" :since="notification.timestamp" :auto-update="60" :locale="$i18n.locale"></timeago>
          <div class="notification-message" :class="{'text-secondary': !notification.new}">
            <icon :name="notification.icon" :class="'text-'+notification.variant"></icon> {{notification.message}}
          </div>
          <small class="notification-url text-secondary">{{notification.url}}</small>
      </b-dropdown-item>
    </b-nav-item-dropdown>
    <div class="notifications-toasts">
      <b-alert v-for="(notification, index) in notifications_new" :key="index" :variant="notification.variant" @dismissed="notification.new=false"
        show dismissible fade>
        <div class="notification-message">
          <icon :name="notification.icon" :class="'text-'+notification.variant"></icon> {{notification.message}}
        </div>
        <small class="notification-url text-secondary">{{notification.url}}</small>
      </b-alert>
    </div>
  </div>
</template>

<script>
export default {
  name: 'pfNotificationCenter',
  computed: {
    notifications () {
      return this.$store.state.notification.all
    },
    notifications_new () {
      return this.$store.state.notification.all.filter(n => n.new)
    },
    isEmpty () {
      return this.$store.state.notification.all.length === 0
    }
  }
}
</script>

<style lang="scss">
.notifications-toasts {
    width: 30vw;
    position: absolute;
    top: 1rem;
    right: 1rem;
    z-index: 9999;
}

.navbar .navbar-nav>.nav-item.notifications {
    font-weight: inherit;
    text-transform: none;
}
.notifications .dropdown-menu {
    width: 30vw;
}
.dropdown-item {
  outline: none;
  .notification-message {
    white-space: normal;
  }
}
</style>
