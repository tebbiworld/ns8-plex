<!--
  Copyright (C) 2026 tebbi
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title"><h2>{{ $t("settings.title") }}</h2></cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification kind="error" :title="$t('action.get-configuration')" :description="error.getConfiguration" :showCloseButton="false" />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <!-- Publishing -->
            <cv-text-input
              :label="$t('settings.host')"
              v-model.trim="host"
              :placeholder="$t('settings.host_placeholder')"
              :helper-text="$t('settings.host_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              :invalid-message="$t(error.host)"
              ref="host"
            ></cv-text-input>
            <cv-toggle value="lets_encrypt" :label="$t('settings.lets_encrypt')" v-model="lets_encrypt" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>
            <cv-toggle value="http2https" :label="$t('settings.http2https')" v-model="http2https" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>
            <cv-dropdown
              :label="$t('settings.network_mode')"
              v-model="network_mode"
              :helper-text="$t('settings.network_mode_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              :invalid-message="$t(error.network_mode)"
              class="field"
            >
              <cv-dropdown-item value="bridge">{{ $t("settings.network_bridge") }}</cv-dropdown-item>
              <cv-dropdown-item value="host">{{ $t("settings.network_host") }}</cv-dropdown-item>
            </cv-dropdown>

            <!-- Media -->
            <h4 class="section">{{ $t("settings.media_section") }}</h4>
            <cv-text-area
              :label="$t('settings.media_paths')"
              v-model="media_paths_text"
              :placeholder="$t('settings.media_paths_placeholder')"
              :helper-text="$t('settings.media_paths_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              :invalid-message="$t(error.media_paths)"
              ref="media_paths"
              rows="4"
              class="field"
            ></cv-text-area>
            <cv-toggle value="media_require_mount" :label="$t('settings.media_require_mount')" v-model="media_require_mount" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>
            <NsInlineNotification kind="info" :title="$t('settings.media_hint_title')" :description="$t('settings.media_hint_desc')" :showCloseButton="false" class="info-tile" />

            <!-- Server -->
            <h4 class="section">{{ $t("settings.server_section") }}</h4>
            <NsInlineNotification
              v-if="!loading.getConfiguration"
              :kind="server_claimed ? 'success' : 'warning'"
              :title="server_claimed ? $t('settings.claimed_title', { name: server_name || '-' }) : $t('settings.unclaimed_title')"
              :description="server_claimed ? $t('settings.claimed_desc', { version: plex_version || '-' }) : $t('settings.unclaimed_desc')"
              :showCloseButton="false"
              class="info-tile"
            />
            <cv-text-input
              v-if="!server_claimed"
              type="password"
              :label="$t('settings.plex_claim')"
              v-model.trim="plex_claim"
              :placeholder="$t('settings.plex_claim_placeholder')"
              :helper-text="$t('settings.plex_claim_helper')"
              :password-hide-label="$t('settings.hide')"
              :password-show-label="$t('settings.show')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-text-input>
            <cv-toggle value="hw_transcoding" :label="$t('settings.hw_transcoding')" v-model="hw_transcoding" :disabled="loading.getConfiguration || loading.configureModule" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>
            <div v-if="error.hw_transcoding" class="bx--form-requirement error-text">{{ $t(error.hw_transcoding) }}</div>
            <cv-text-input
              :label="$t('settings.timezone')"
              v-model.trim="timezone"
              :placeholder="$t('settings.timezone_placeholder')"
              :helper-text="$t('settings.timezone_helper')"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="field"
            ></cv-text-input>

            <NsInlineNotification v-if="url" kind="info" :title="$t('settings.web_url')" :description="$t('settings.web_url_desc', { url })" :showCloseButton="false" class="info-tile" />
            <NsInlineNotification kind="info" :title="$t('settings.proxy_hint_title')" :description="$t('settings.proxy_hint_desc', { host: host || 'plex.example.org' })" :showCloseButton="false" class="info-tile" />

            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification kind="error" :title="$t('action.configure-module')" :description="error.configureModule" :showCloseButton="false" />
              </cv-column>
            </cv-row>
            <NsButton kind="primary" :icon="Save20" :loading="loading.configureModule" :disabled="loading.getConfiguration || loading.configureModule">{{ $t("settings.save") }}</NsButton>
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import { QueryParamService, UtilService, TaskService, IconService, PageTitleService } from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [TaskService, IconService, UtilService, QueryParamService, PageTitleService],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: { page: "settings" },
      urlCheckInterval: null,
      host: "",
      lets_encrypt: false,
      http2https: true,
      network_mode: "bridge",
      media_paths_text: "",
      media_require_mount: true,
      hw_transcoding: false,
      plex_claim: "",
      timezone: "UTC",
      url: "",
      server_claimed: false,
      server_name: "",
      plex_version: "",
      loading: { getConfiguration: false, configureModule: false },
      error: { getConfiguration: "", configureModule: "", host: "", network_mode: "", media_paths: "", hw_transcoding: "" },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    media_paths() {
      return this.media_paths_text
        .split(/\r?\n/)
        .map((p) => p.trim())
        .filter((p) => p.length > 0);
    },
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  created() {
    this.getConfiguration();
  },
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();
      this.core.$root.$once(`${taskAction}-aborted-${eventId}`, this.getConfigurationAborted);
      this.core.$root.$once(`${taskAction}-completed-${eventId}`, this.getConfigurationCompleted);
      const res = await to(this.createModuleTaskForApp(this.instanceName, { action: taskAction, extra: { title: this.$t("action." + taskAction), isNotificationHidden: true, eventId } }));
      const err = res[0];
      if (err) {
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      this.loading.getConfiguration = false;
      const c = taskResult.output;
      this.host = c.host || "";
      this.lets_encrypt = !!c.lets_encrypt;
      this.http2https = c.http2https !== undefined ? !!c.http2https : true;
      this.network_mode = c.network_mode || "bridge";
      this.media_paths_text = (c.media_paths || []).join("\n");
      this.media_require_mount = c.media_require_mount !== undefined ? !!c.media_require_mount : true;
      this.hw_transcoding = !!c.hw_transcoding;
      this.timezone = c.timezone || "UTC";
      this.url = c.url || "";
      this.server_claimed = !!c.server_claimed;
      this.server_name = c.server_name || "";
      this.plex_version = c.plex_version || "";
      // one-time token, never echoed back
      this.plex_claim = "";
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);
      let ok = true;
      const fail = (field, msg) => {
        this.error[field] = msg;
        if (ok) this.focusElement(field);
        ok = false;
      };
      if (!this.host) fail("host", "common.required");
      for (const p of this.media_paths) {
        if (!p.startsWith("/") || /[\s,:]/.test(p) || p === "/") {
          fail("media_paths", "settings.media_path_invalid");
          break;
        }
      }
      return ok;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusSet = false;
      for (const e of validationErrors) {
        if (e.field !== "(root)") {
          const detail = e.value && typeof e.value === "string" ? ` (${e.value})` : "";
          this.error[e.field] = this.$t("settings." + e.error) + detail;
          if (!focusSet) {
            this.focusElement(e.field);
            focusSet = true;
          }
        }
      }
    },
    async configureModule() {
      if (!this.validateConfigureModule()) return;
      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();
      this.core.$root.$once(`${taskAction}-aborted-${eventId}`, this.configureModuleAborted);
      this.core.$root.$once(`${taskAction}-validation-failed-${eventId}`, this.configureModuleValidationFailed);
      this.core.$root.$once(`${taskAction}-completed-${eventId}`, this.configureModuleCompleted);
      const data = {
        host: this.host,
        lets_encrypt: this.lets_encrypt,
        http2https: this.http2https,
        network_mode: this.network_mode,
        media_paths: this.media_paths,
        media_require_mount: this.media_require_mount,
        hw_transcoding: this.hw_transcoding,
        plex_claim: this.plex_claim,
        timezone: this.timezone || "UTC",
      };
      const res = await to(this.createModuleTaskForApp(this.instanceName, {
        action: taskAction,
        data,
        extra: { title: this.$t("settings.configure_instance", { instance: this.instanceName }), description: this.$t("common.processing"), eventId },
      }));
      const err = res[0];
      if (err) {
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.field { margin-top: $spacing-06; }
.toggle { margin-top: $spacing-06; }
.info-tile { margin-top: $spacing-06; }
.section { margin-top: $spacing-07; margin-bottom: $spacing-03; }
.error-text { display: block; color: #da1e28; margin-top: $spacing-03; }
</style>
