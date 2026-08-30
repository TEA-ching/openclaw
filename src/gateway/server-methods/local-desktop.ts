import {
  ErrorCodes,
  errorShape,
  validateLocalDesktopObserveParams,
} from "../../../packages/gateway-protocol/src/index.js";
import type { GatewayRequestHandlers } from "./types.js";
import { assertValidParams } from "./validation.js";

export const localDesktopHandlers: GatewayRequestHandlers = {
  "desktop.observeLocal": async ({ params, respond }) => {
    if (!assertValidParams(params, validateLocalDesktopObserveParams, "desktop.observeLocal", respond)) {
      return;
    }
    const vncPassword = process.env.VNC_PASSWORD;
    if (!vncPassword) {
      respond(
        false,
        undefined,
        errorShape(ErrorCodes.UNAVAILABLE, "local desktop observe is unavailable: no VNC server"),
      );
      return;
    }
    const { LOCAL_DESKTOP_OBSERVE_PATH, LOCAL_DESKTOP_VNC_PORT, mintLocalDesktopObserverToken } =
      await import("../desktop/local-desktop-bridge.js");
    const minted = mintLocalDesktopObserverToken({
      kind: "tcp",
      host: "127.0.0.1",
      port: LOCAL_DESKTOP_VNC_PORT,
    });
    respond(
      true,
      {
        transport: "rfb",
        wsPath: `${LOCAL_DESKTOP_OBSERVE_PATH}?token=${minted.token}`,
        expiresAtMs: minted.expiresAtMs,
        vncPassword,
      },
      undefined,
    );
  },
};
