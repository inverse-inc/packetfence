
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('RADIUS Audit Log Entry')}} <strong v-text="id"></strong></h4>
      </b-card-header>
      <b-tabs ref="tabs" v-model="tabIndex" card>

        <b-tab title="Node Information">
          <template slot="title">
            {{ $t('Node Information') }}
          </template>
          <b-row>
            <b-col>
              <pf-form-row :column-label="$t('MAC Address')">
                {{ item.mac }}
              </pf-form-row>
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="Switch Information">
          <template slot="title">
            {{ $t('Switch Information') }}
          </template>
          <b-row>
            <b-col>
              <pf-form-row :column-label="$t('Switch ID')">
                {{ item.switch_id }}
              </pf-form-row>
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="RADIUS">
          <b-row>
            <b-col>
              <pf-form-row :column-label="$t('Request Time')">
                {{ item.request_time }}
              </pf-form-row>
            </b-col>
          </b-row>
        </b-tab>

      </b-tabs>
    </b-card>
  </b-form>
</template>

<script>
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'RadiusLogView',
  components: {
    pfFormRow
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: String // from router
  },
  data () {
    return {
      tabIndex: 0,
      tabTitle: ''
    }
  },
  computed: {
    item () {
      return this.$store.state[this.storeName].cache[this.id]
    },
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    }
  },
  methods: {
    ifTab (set) {
      return this.$refs.tabs && set.includes(this.$refs.tabs.tabs[this.tabIndex].title)
    },
    close () {
      this.$router.push({ name: 'radiuslogs' })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  mounted () {
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>
