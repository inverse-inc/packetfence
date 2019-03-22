<template>
    <b-form-row>
        <b-col cols="1"></b-col>
        <b-col cols="2">
            <h6 class="col-form-label text-center" v-t="'Endpoint'"></h6>
        </b-col>
        <b-col></b-col>
        <b-col cols="2">
            <h6 class="col-form-label text-center" v-t="'Device Profiling'"></h6>
        </b-col>
        <b-col></b-col>
        <b-col cols="2">
            <h6 class="col-form-label text-center" v-t="'Data Usage'"></h6>
        </b-col>
        <b-col></b-col>
        <b-col cols="2">
            <h6 class="col-form-label text-center" v-t="'Event'"></h6>
        </b-col>
        <b-col cols="1"></b-col>
    </b-form-row>
</template>

<script>
export default {
  name: 'pf-form-security-event-trigger-header'
}
</script>
