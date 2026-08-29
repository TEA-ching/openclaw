import { consume } from "@lit/context";
import { html } from "lit";
import { state } from "lit/decorators.js";
import { titleForRoute } from "../../app-navigation.ts";
import { applicationContext, type ApplicationContext } from "../../app/context.ts";
import { renderSettingsWorkspace } from "../../components/settings-workspace.ts";
import { t } from "../../i18n/index.ts";
import { GatewayPageController } from "../../lit/gateway-page-controller.ts";
import { OpenClawLightDomElement } from "../../lit/openclaw-element.ts";
import { renderVnc } from "./view.ts";

class VncPage extends OpenClawLightDomElement {
  @consume({ context: applicationContext, subscribe: true })
  private context!: ApplicationContext;

  @state() private connectionStatus: "connecting" | "connected" | "failed" | "disconnected" =
    "connecting";
  @state() private errorMessage: string | null = null;

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
    this.connectVnc();
  }

  private async connectVnc() {
    try {
      // Import dynamique de noVNC pour éviter de charger le code inutilement
      const { default: RFB } = await import("@novnc/novnc");

      // Configuration du client RFB (Remote Frame Buffer)
      const rfb = new RFB(document.getElementById("vnc-screen"), {
        target: window.location.hostname,
        port: 5900,
        protocol: "ws",
        encrypt: false,
        true_color: true,
        local_cursor: true,
        view_only: false,
        shared: true,
        // Désactiver l'UI par défaut de noVNC pour une intégration propre
        showDotCursor: false,
      });

      rfb.addEventListener("connect", () => {
        this.connectionStatus = "connected";
        this.errorMessage = null;
      });

      rfb.addEventListener("disconnect", (e) => {
        this.connectionStatus = "disconnected";
        this.errorMessage = e.detail.reason || t("vnc.disconnected");
      });

      rfb.addEventListener("credentialsrequired", () => {
        // Si des credentials sont nécessaires, on peut les gérer ici
        // Pour l'instant, on suppose que le serveur x11vnc n'en nécessite pas
      });

      rfb.addEventListener("securityfailure", (e) => {
        this.connectionStatus = "failed";
        this.errorMessage = e.detail.reason || t("vnc.connectionFailed");
      });

      rfb.addEventListener("fatal", (e) => {
        this.connectionStatus = "failed";
        this.errorMessage = e.detail.reason || t("vnc.connectionFailed");
      });

      // Stocker la référence pour pouvoir déconnecter plus tard
      (this as any).rfbInstance = rfb;
    } catch (error) {
      this.connectionStatus = "failed";
      this.errorMessage = String(error);
      console.error("Failed to load noVNC:", error);
    }
  }

  private disconnectVnc() {
    if ((this as any).rfbInstance) {
      try {
        (this as any).rfbInstance.disconnect();
      } catch (e) {
        console.warn("Error disconnecting VNC:", e);
      }
      (this as any).rfbInstance = null;
    }
  }

  override render() {
    const vncView = renderVnc({
      connectionStatus: this.connectionStatus,
      errorMessage: this.errorMessage,
      onRetry: () => this.connectVnc(),
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
