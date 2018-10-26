<template>
  <b-navbar-nav class="notifications">
    <b-nav-item-dropdown v-if="isAuthenticated" @click.native.stop.prevent @hidden="markAsRead()" :disabled="isEmpty" right no-caret>
      <template slot="button-content">
        <icon-counter name="bell" v-model="count" :variant="variant"></icon-counter>
      </template>
      <!-- menu items -->
      <div class="notifications-scroll">
        <div v-for="(notification) in notifications" :key="notification.id">
          <b-dropdown-item>
            <small>
              <b-row no-gutters>
                <b-col>
                  <div class="notification-message" :class="{'text-secondary': !notification.unread}">
                    <icon :name="notification.icon" class="mr-1" :class="'text-'+notification.variant"></icon> <span :class="{ 'font-weight-bold': notification.unread }">{{notification.message}}</span>
                  </div>
                  <small class="notification-url text-secondary">{{notification.url}}</small>
                </b-col>
                <b-col cols="auto" class="ml-3 text-right">
                  <timeago :class="{'text-secondary': !notification.unread}" :datetime="notification.timestamp" :auto-update="60" :locale="$i18n.locale"></timeago>
                  <br/>
                  <b-badge pill v-if="notification.success" variant="success" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.success + ' ' + $t('succeeded')">{{notification.success}}</b-badge>
                  <b-badge pill v-if="notification.skipped" variant="warning" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.skipped + ' ' + $t('skipped')">{{notification.skipped}}</b-badge>
                  <b-badge pill v-if="notification.failed" variant="danger" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.failed + ' ' + $t('failed')">{{notification.failed}}</b-badge>
                </b-col>
              </b-row>
            </small>
          </b-dropdown-item>
          <b-dropdown-divider></b-dropdown-divider>
        </div>
      </div>
      <b-dropdown-item class="text-right">
        <b-button size="sm" variant="outline-secondary" v-t="'Clear All'" @click="clear()"></b-button>
      </b-dropdown-item>
    </b-nav-item-dropdown>
    <!-- toasts -->
    <div class="notifications-toasts">
      <b-alert v-for="(notification) in newNotifications" :key="notification.id" variant="secondary"
        @dismissed="dismiss(notification)" :show="notification.new" fade dismissible>
        <b-row class="justify-content-md-center">
          <b-col>
            <div class="notification-message">
              <icon :name="notification.icon" :class="'text-'+notification.variant"></icon> {{notification.message}}
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
  </b-navbar-nav>
</template>

<script>
import IconCounter from '@/components/IconCounter'

export default {
  name: 'pfNotificationCenter',
  components: {
    'icon-counter': IconCounter
  },
  props: {
    isAuthenticated: {
      default: false
    }
  },
  computed: {
    notifications () {
      return this.$store.state.notification.all
    },
    newNotifications () {
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
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/breakpoints";
@import "../styles/variables";

.notifications-toasts {
    width: 30vw;
    position: absolute;
    top: 1rem;
    right: 1rem;
    z-index: 9999;
}

.navbar .navbar-nav.notifications>.nav-item {
    font-weight: inherit;
    text-transform: none;
}
.notifications .dropdown-menu {
  width: 100%;
  @include media-breakpoint-up(sm) {
    width: 30vw;
  }
}
.notifications-scroll {
  overflow: auto;
  max-height: 75vh;
}
.notifications .dropdown-item {
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
