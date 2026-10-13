// Local Lit helpers for the VNC page. Upstream moved the shared settings
// workspace/status helpers to Solid components; this fork-only page stays Lit.
import { html, type TemplateResult } from "lit";
import "../../styles/settings.css";

type VncStatusKind = "ok" | "warn" | "danger" | "muted";

export function renderVncWorkspace(body: unknown, options: { fillHeight?: boolean } = {}) {
  const className = options.fillHeight
    ? "settings-workspace settings-workspace--fill-height"
    : "settings-workspace";
  return html`
    <section class=${className}>
      <div class="settings-workspace__body">${body}</div>
    </section>
  `;
}

export function renderVncStatus(props: { kind: VncStatusKind; label: unknown }): TemplateResult {
  const modifier = props.kind === "muted" ? "" : ` settings-status--${props.kind}`;
  return html`
    <span class="settings-status${modifier}">
      <span class="settings-status__dot"></span>
      <span>${props.label}</span>
    </span>
  `;
}
