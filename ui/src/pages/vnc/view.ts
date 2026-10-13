// Control UI view renders VNC screen content.
import { html, nothing } from "lit";
import { renderVncStatus } from "./vnc-layout.ts";
import { t } from "../../i18n/index.ts";

type VncProps = {
  connectionStatus: "connecting" | "connected" | "failed" | "disconnected";
  errorMessage: string | null;
  clipboardText: string;
  onClipboardInput: (text: string) => void;
  onRetry: () => void;
};

export function renderVnc(props: VncProps) {
  let statusContent;

  switch (props.connectionStatus) {
    case "connecting":
      statusContent = renderVncStatus({
        kind: "muted",
        label: t("vnc.connecting"),
      });
      break;
    case "connected":
      statusContent = renderVncStatus({
        kind: "ok",
        label: t("common.connected"),
      });
      break;
    case "disconnected":
      statusContent = html`
        <div class="settings-row__text">
          <span class="settings-row__title">
            ${renderVncStatus({ kind: "warn", label: t("vnc.disconnected") })}
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
            ${renderVncStatus({ kind: "danger", label: t("vnc.connectionFailed") })}
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
    <div id="vnc-screen" class="vnc-workspace__screen">
      ${props.connectionStatus === "connected"
        ? nothing
        : html`<div
            style="display: flex; justify-content: center; align-items: center; height: 100%;"
          >
            ${statusContent}
          </div>`}
    </div>
  `;

  const clipboard = html`
    <div class="vnc-workspace__clipboard">
      <label class="vnc-workspace__clipboard-label" for="vnc-clipboard">
        ${t("vnc.clipboardLabel")}
      </label>
      <textarea
        id="vnc-clipboard"
        class="settings-input vnc-workspace__clipboard-input"
        rows="2"
        placeholder=${t("vnc.clipboardPlaceholder")}
        title=${t("vnc.clipboardHint")}
        .value=${props.clipboardText}
        @input=${(event: InputEvent) =>
          props.onClipboardInput((event.target as HTMLTextAreaElement).value)}
      ></textarea>
    </div>
  `;

  return html`
    <div class="vnc-workspace">
      <div class="settings-row vnc-workspace__status">${statusContent}</div>
      ${clipboard} ${vncScreen}
    </div>
  `;
}
