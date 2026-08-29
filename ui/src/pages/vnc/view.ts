// Control UI view renders VNC screen content.
import { html, nothing } from "lit";
import {
  renderSettingsPage,
  renderSettingsRow,
  renderSettingsStatus,
} from "../../components/settings-ui.ts";
import { t } from "../../i18n/index.ts";

type VncProps = {
  connectionStatus: "connecting" | "connected" | "failed" | "disconnected";
  errorMessage: string | null;
  onRetry: () => void;
};

export function renderVnc(props: VncProps) {
  let statusContent;

  switch (props.connectionStatus) {
    case "connecting":
      statusContent = renderSettingsStatus({
        kind: "info",
        label: t("vnc.connecting"),
      });
      break;
    case "connected":
      statusContent = renderSettingsStatus({
        kind: "ok",
        label: t("common.connected"),
      });
      break;
    case "disconnected":
      statusContent = html`
        <div class="settings-row__text">
          <span class="settings-row__title">
            ${renderSettingsStatus({ kind: "warn", label: t("vnc.disconnected") })}
          </span>
          ${props.errorMessage
            ? html`<span class="settings-row__desc">${props.errorMessage}</span>`
            : nothing}
          <button class="btn" @click=${props.onRetry}>${t("common.retry")}</button>
        </div>
      `;
      break;
    case "failed":
      statusContent = html`
        <div class="settings-row__text">
          <span class="settings-row__title">
            ${renderSettingsStatus({ kind: "danger", label: t("vnc.connectionFailed") })}
          </span>
          ${props.errorMessage
            ? html`<span class="settings-row__desc">${props.errorMessage}</span>`
            : nothing}
          <button class="btn" @click=${props.onRetry}>${t("common.retry")}</button>
        </div>
      `;
      break;
  }

  const vncScreen = html`
    <div
      id="vnc-screen"
      style="width: 100%; height: calc(100vh - 200px); border: 1px solid var(--border-color); border-radius: 8px; overflow: hidden;"
    >
      ${props.connectionStatus === "connected"
        ? nothing
        : html`<div
            style="display: flex; justify-content: center; align-items: center; height: 100%;"
          >
            ${statusContent}
          </div>`}
    </div>
  `;

  return renderSettingsPage(
    html`
      <div class="settings-row">${statusContent}</div>
      ${vncScreen}
    `,
    { wide: true },
  );
}
