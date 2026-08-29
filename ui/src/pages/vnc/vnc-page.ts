import { consume } from "@lit/context";
import type { LocalDesktopObserveResult } from "@openclaw/gateway-protocol";
import { html } from "lit";
import { state } from "lit/decorators.js";
import { titleForRoute } from "../../app-navigation.ts";
import { applicationContext, type ApplicationContext } from "../../app/context.ts";
import {
  DesktopClient,
  type DesktopConnectionHandle,
} from "../../components/desktop/desktop-client.ts";
import { renderSettingsWorkspace } from "../../components/settings-workspace.ts";
import { t } from "../../i18n/index.ts";
import { formatUiError } from "../../lib/format-error.ts";
import { GatewayPageController } from "../../lit/gateway-page-controller.ts";
import { OpenClawLightDomElement } from "../../lit/openclaw-element.ts";
import { renderVnc } from "./view.ts";

class VncPage extends OpenClawLightDomElement {
  @consume({ context: applicationContext, subscribe: true })
  private context!: ApplicationContext;

  @state() private connectionStatus: "connecting" | "connected" | "failed" | "disconnected" =
    "connecting";
  @state() private errorMessage: string | null = null;

  private readonly desktopClient = new DesktopClient();
  private connection: DesktopConnectionHandle | null = null;
  private operationId = 0;

  private readonly gateway = new GatewayPageController(this, {
    getGateway: () => this.context?.gateway,
    onIdentityChange: () => {
      this.connectionStatus = "connecting";
      this.errorMessage = null;
    },
    invalidateRequests: () => {
      this.connectionStatus = "connecting";
      this.errorMessage = null;
    },
    onSnapshot: () => {
      this.ensureVncConnection();
    },
  });

  override disconnectedCallback() {
    this.disconnectVnc();
    super.disconnectedCallback();
  }

  private ensureVncConnection() {
    if (!this.gateway.connected) {
      return;
    }
    void this.connectVnc();
  }

  private async connectVnc() {
    const client = this.gateway.client;
    if (!client) {
      return;
    }
    this.disconnectVnc();
    const operationId = ++this.operationId;
    this.connectionStatus = "connecting";
    this.errorMessage = null;
    try {
      const observed = await client.request<LocalDesktopObserveResult>("desktop.observeLocal", {});
      if (operationId !== this.operationId) {
        return;
      }
      await this.updateComplete;
      const target = this.querySelector<HTMLElement>("#vnc-screen");
      if (!target) {
        throw new Error("VNC render target is unavailable");
      }
      const connection = await this.desktopClient.connect({
        wsUrl: observed.wsPath,
        gatewayUrl: client.gatewayUrl,
        password: observed.vncPassword,
        viewOnly: false,
        target,
        onConnect: () => {
          if (operationId === this.operationId) {
            this.connectionStatus = "connected";
            this.errorMessage = null;
          }
        },
        onDisconnect: (detail) => {
          if (operationId === this.operationId) {
            this.connectionStatus = "disconnected";
            this.errorMessage = detail.reason || t("vnc.disconnected");
          }
        },
        onSecurityFailure: (detail) => {
          if (operationId === this.operationId) {
            this.connectionStatus = "failed";
            this.errorMessage = detail.reason || t("vnc.connectionFailed");
          }
        },
      });
      if (operationId !== this.operationId) {
        connection.disconnect();
        return;
      }
      this.connection = connection;
    } catch (error) {
      if (operationId !== this.operationId) {
        return;
      }
      this.connectionStatus = "failed";
      this.errorMessage = formatUiError(error, t("vnc.connectionFailed"));
    }
  }

  private disconnectVnc() {
    this.operationId += 1;
    this.connection?.disconnect();
    this.connection = null;
  }

  override render() {
    const vncView = renderVnc({
      connectionStatus: this.connectionStatus,
      errorMessage: this.errorMessage,
      onRetry: () => void this.connectVnc(),
    });

    return html`
      <section class="content-header">
        <div>
          <div class="page-title">${titleForRoute("vnc")}</div>
        </div>
      </section>
      ${renderSettingsWorkspace(vncView)}
    `;
  }
}

if (!customElements.get("openclaw-vnc-page")) {
  customElements.define("openclaw-vnc-page", VncPage);
}
