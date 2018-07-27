<template>
        <b-row>
            <b-col cols="12" md="3" xl="2" class="bd-sidebar">
                <div class="bd-search d-flex align-items-center">
                    <b-form-input type="text" :placeholder="$t('Filter')"></b-form-input>
                    <b-btn class="bd-search-docs-toggle d-md-none p-0 ml-3" aria-controls="bd-docs-nav">=</b-btn>
                </div>
                <b-collapse is-nav class="bd-links" id="bd-docs-nav">
                    <div class="bd-toc-item active">
                        <b-nav vertical class="bd-sidenav">
                            <div class="bd-toc-link" v-t="'Nodes'"></div>
                            <b-nav-item to="/nodes/search" replace>{{ $t('Search') }}</b-nav-item>
                            <b-nav-item to="/nodes/create" replace>{{ $t('Create') }}</b-nav-item>

                            <hr/>
                            <div class="bd-toc-link" v-t="'Standard Searches'"></div>
                            <b-nav-item  @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"violation.open_count","op":"greater_than_equals","value":"1"}]}]})}}' active-class="secondary" exact>{{ $t('Open Violations') }}</b-nav-item>
                            <b-nav-item  @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"violation.close_count","op":"greater_than_equals","value":"1"}]}]})}}' active-class="secondary" exact>{{ $t('Closed Violations') }}</b-nav-item>
                            <b-nav-item  @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"online","op":"not_equals","value":"on"}]}]})}}' active-class="secondary" exact>{{ $t('Offline Nodes') }}</b-nav-item>
                            <b-nav-item  @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"online","op":"equals","value":"on"}]}]})}}' active-class="secondary" exact>{{ $t('Online Nodes') }}</b-nav-item>

                            <!-- Standard Searches > Switch Groups -->
                            <div class="bd-toc-link" v-b-toggle="'accordionSwitchGroups'">
                              {{ $t('Switch Groups') }}
                              <icon class="float-right mt-1" name="chevron-down"></icon>
                            </div>
                            <b-collapse id="accordionSwitchGroups" ref="accordionSwitchGroups" is-nav>
                              <div v-for="switchGroup in switchGroups" :key="switchGroup.id">
                                <div class="bd-toc-link" v-b-toggle="`accordionSwitchGroup${switchGroup.group}`">
                                  {{ switchGroup.group }}
                                  <icon class="float-right mt-1" name="chevron-down"></icon>
                                </div>
                                <b-collapse :id="`accordionSwitchGroup${switchGroup.group}`" :ref="`accordionSwitchGroup${switchGroup.group}`" is-nav>
                                  <b-nav-item @click.stop v-for="sw in switchGroup.switches" :key="sw.id" v-if="sw.id !== 'default'" :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"locationlog.switch","op":"equals","value":getIpFromCIDR(sw.id)}]}]})}}' active-class="secondary" exact>
                                    <blockquote class="mb-0">
                                      {{ sw.id }}<br/>
                                      {{ sw.description }}
                                    </blockquote>
                                  </b-nav-item>
                                </b-collapse>
                              </div>
                            </b-collapse>

                            <!-- Standard Searches > Switch Roles -->
                            <div class="bd-toc-link" v-b-toggle="'accordionRoles'">
                              {{ $t('Roles') }}
                              <icon class="float-right mt-1" name="chevron-down"></icon>
                            </div>
                            <b-collapse id="accordionRoles" ref="accordionRoles" is-nav>
                                <b-nav-item @click.stop v-for="role in roles" :key="role.name" :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"category_id","op":"equals","value":role.category_id}]}]})}}' active-class="secondary" exact>{{role.name}}</b-nav-item>
                            </b-collapse>

                            <!-- Standard Searches > OS -->
                            <div class="bd-toc-link" v-b-toggle="'accordionOs'">
                              {{ $t('OS') }}
                              <icon class="float-right mt-1" name="chevron-down"></icon>
                            </div>
                            <b-collapse id="accordionOs" ref="accordionOs" is-nav>
                                <b-nav-item @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Windows OS"}]}]})}}' active-class="secondary" exact>{{ $t('Windows') }}</b-nav-item>
                                <b-nav-item @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Linux OS"}]}]})}}' active-class="secondary" exact>{{ $t('Linux') }}</b-nav-item>
                                <b-nav-item @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Mac OS X or macOS"}]}]})}}' active-class="secondary" exact>{{ $t('MacOS') }}</b-nav-item>
                                <b-nav-item @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Windows Phone OS"},{"field":"device_class","op":"equals","value":"WebOS"},{"field":"device_class","op":"equals","value":"iOS"},{"field":"device_class","op":"equals","value":"Palm OS"},{"field":"device_class","op":"equals","value":"Android OS"},{"field":"device_class","op":"equals","value":"watchOS"},{"field":"device_class","op":"equals","value":"Phone, Tablet or Wearable"},{"field":"mac","op":"equals","value":"BlackBerry OS"}]}]})}}' active-class="secondary" exact>{{ $t('Mobile Devices') }}</b-nav-item>
                                <b-nav-item @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Gaming Console"}]}]})}}' active-class="secondary" exact>{{ $t('Gaming Console') }}</b-nav-item>
                                <b-nav-item @click.stop :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"VoIP Device"}]}]})}}' active-class="secondary" exact>{{ $t('VoIP Device') }}</b-nav-item>
                            </b-collapse>
                          </b-nav>
                        <hr/>
                        <pf-saved-search :storeName="'$_' + this.$options.name.toLowerCase()" :routeName="this.$options.name.toLowerCase()"/>
                    </div>
                </b-collapse>
            </b-col>
            <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
                <transition name="slide-bottom">
                    <router-view></router-view>
                </transition>
            </b-col>
        </b-row>
</template>

<script>
import pfMixinSavedSearch from '@/components/pfMixinSavedSearch'

export default {
  name: 'Nodes',
  mixins: [
    pfMixinSavedSearch
  ],
  components: {
    'pf-saved-search': pfMixinSavedSearch
  },
  computed: {
    roles () {
      return this.$store.state.config.roles
    },
    switches () {
      return this.$store.state.config.switches
    },
    switchGroups () {
      return this.$store.getters['config/groupedSwitches']
    }
  },
  methods: {
    getIpFromCIDR (cidr) {
      return cidr.split('/', 1)[0] || cidr
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getSwitches')
  }
}
</script>

<style>
.bd-sidenav .navbar-collapse {
  background-color: rgba(0, 0, 0, 0.125);
}
.bd-sidenav :not(.collapsed) > svg {
  transition: transform 300ms ease;
}
.bd-sidenav .collapsed > svg {
  transform: rotate( -180deg );
  transition: transform 300ms ease;
}
.bd-sidenav .bd-toc-link:hover > svg {
  color: #dc3545;
  transition: all 300ms ease;
}
.bd-sidenav .bd-toc-link[role=button] {
  cursor: pointer;
}
</style>
