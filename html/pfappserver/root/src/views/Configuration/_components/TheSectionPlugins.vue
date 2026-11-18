<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="plug" scale="1.5"></icon>
            {{ $t('Plugins') }}
        </h4>
        <p v-t="'Plugins are packages installed on top of PacketFence. Each adds its own configuration here:'"></p>
        <dl>
            <template v-for="plugin in plugins">
                <dt :key="`dt-${plugin.id}`">
                    <icon v-if="plugin.icon" class="mr-1" :name="plugin.icon"></icon>
                    <router-link :to="plugin.path">{{ plugin.title }}</router-link>
                </dt>
                <dd :key="`dd-${plugin.id}`">{{ plugin.description }}</dd>
            </template>
        </dl>
    </b-container>
</template>
<script>
/**
 * The Plugins section of Configuration: the plugins of the section, with the
 * icon, title and description of their manifest.
 */
import { sectionPlugins } from '@/plugins'

export default {
  name: 'the-section-plugins',
  computed: {
    plugins: () => sectionPlugins()
  }
}
</script>
