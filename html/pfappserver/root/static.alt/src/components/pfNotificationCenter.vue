<template>
  <b-navbar-nav class="notifications">
    <b-nav-item-dropdown v-if="isAuthenticated" :extra-menu-classes="visible ? 'd-flex flex-column' : ''" right no-caret
      @click.native.stop.prevent @show="show()" @hidden="markAsRead()" :disabled="isEmpty">
      <template slot="button-content">
        <icon-counter name="bell" v-model="count" :variant="variant"></icon-counter>
      </template>
      <!-- menu items -->
      <div class="flex-grow-1 notifications-scroll">
        <div v-for="(notification) in notifications" :key="notification.id">
          <b-dropdown-item>
            <small>
              <b-row no-gutters>
                <b-col>
                  <div class="notification-message" :class="{'text-secondary': !notification.unread}">
                    <b-badge pill v-if="notification.value" class="mr-2" :variant="notification.variant">{{notification.value}}</b-badge>
                    <icon v-else :name="notification.icon" class="mr-1" :class="'text-'+notification.variant"></icon> <span :class="{ 'font-weight-bold': notification.unread }" v-html="notification.message"></span>
                  </div>
                  <small class="notification-url text-secondary">{{notification.url}}</small>
                </b-col>
                <b-col cols="auto" class="ml-3">
                  <b-badge pill v-if="notification.success" variant="success" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.success + ' ' + $t('succeeded')">{{notification.success}}</b-badge>
                  <b-badge pill v-if="notification.skipped" variant="warning" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.skipped + ' ' + $t('skipped')">{{notification.skipped}}</b-badge>
                  <b-badge pill v-if="notification.failed" variant="danger" class="mr-1" v-b-tooltip.hover.top.d300 :title="notification.failed + ' ' + $t('failed')">{{notification.failed}}</b-badge>
                </b-col>
              </b-row>
              <div class="text-right">
                <timeago :class="{'text-secondary': !notification.unread}" :datetime="notification.timestamp" :auto-update="60" :locale="$i18n.locale"></timeago>
              </div>
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
              <b-badge pill v-if="notification.value" class="mr-2" :variant="notification.variant">{{notification.value}}</b-badge>
              <icon v-else :name="notification.icon" class="mr-1" :class="'text-'+notification.variant"></icon> <span v-html="notification.message"></span>
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
  name: 'pf-notification-center',
  components: {
    'icon-counter': IconCounter
  },
  props: {
    isAuthenticated: {
      default: false
    }
  },
  data () {
    return {
      visible: false
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
    show () {
      this.visible = true
    },
    markAsRead () {
      this.visible = false
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
$enable-shadows: true;

.notifications-toasts {
    position: absolute;
    z-index: 9999;
    top: .5rem; // in case of a single one-line notification, center the notification in the top navbar
    right: 3rem; // keep the notification bell icon visible in the top navbar
    width: 30vw;
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

  &.show {
    @include box-shadow($dropdown-box-shadow);
    animation: scale-up-center 0.25s cubic-bezier(0.18, 1.25, 0.40, 1.00) both;
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

@keyframes scale-up-center {
  0% {
    opacity: 0;
    transform: scale(0.85);
  }
  100% {
    opacity: 1;
    transform: scale(1);
  }
}
</style>
