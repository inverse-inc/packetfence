<template>
  <div class="notifications">
    <b-nav-item-dropdown @click.native.stop.prevent @hidden="markAsRead()" :disabled="isEmpty" right no-caret>
      <template slot="button-content">
        <icon-counter name="bell" v-model="count" :variant="variant"></icon-counter>
      </template>
      <!-- menu items -->
      <div v-for="(notification, index) in notifications" :key="index">
        <b-dropdown-item class="border-right" :class="'border-'+notification.variant">
          <small>
            <timeago class="float-right" :class="{'text-secondary': !notification.unread}" :datetime="notification.timestamp" :auto-update="60" :locale="$i18n.locale"></timeago>
            <div class="notification-message" :class="{'text-secondary': !notification.unread}">
              <icon :name="notification.icon" :class="'text-'+notification.variant"></icon> <span :class="{ 'font-weight-bold': notification.unread }">{{notification.message}}</span>
            </div>
            <small class="notification-url text-secondary">{{notification.url}}</small>
          </small>
        </b-dropdown-item>
        <b-dropdown-divider></b-dropdown-divider>
      </div>
      <b-dropdown-item class="text-right">
        <b-button size="sm" variant="outline-secondary" v-t="'Clear All'" @click="clear()"></b-button>
      </b-dropdown-item>
    </b-nav-item-dropdown>
    <!-- toasts -->
    <div class="notifications-toasts">
      <b-alert v-for="(notification, index) in notifications_new" :key="index" :variant="notification.variant" @dismissed="dismiss(notification)"
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
import IconCounter from '@/components/IconCounter'

export default {
  name: 'pfNotificationCenter',
  components: {
    'icon-counter': IconCounter
  },
  computed: {
    notifications () {
      return this.$store.state.notification.all
    },
    notifications_new () {
      return this.$store.state.notification.all.filter(n => n.new)
    },
    count () {
      return this.unread.length || this.notifications.length
    },
    isEmpty () {
      return this.notifications.length === 0
    },
    unread () {
      return this.$store.state.notification.all.filter(n => n.unread)
    },
    variant () {
      return (this.unread.length > 0) ? 'danger' : 'secondary'
    }
  },
  methods: {
    markAsRead () {
      this.$store.state.notification.all.forEach((notification) => {
        notification.unread = false
      })
    },
    dismiss (notification) {
      notification.new = notification.unread = false
    },
    clear () {
      this.$store.commit('notification/CLEAR')
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
.notifications .dropdown-item{
    &:hover, &:focus {
        background-color: inherit;
    }
}
.dropdown-item {
    outline: none;
    .notification-message {
        white-space: normal;
    }
}
</style>
