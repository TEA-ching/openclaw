// Bridges this Gateway process's own pod-local desktop (x11vnc on 127.0.0.1) to a browser
// noVNC client. Independent of the worker-environments desktop-observe bridge, which is
// gated behind the cloud-workers subsystem and its SSH-tunneled remote worker sessions.
import crypto from "node:crypto";
import type { IncomingMessage } from "node:http";
import type { Duplex } from "node:stream";
import { WebSocket, WebSocketServer, type RawData } from "ws";
import { connectRfbAttachment, type RfbAttachment } from "./attachment.js";

export const LOCAL_DESKTOP_OBSERVE_PATH = "/desktop/observe-local";
export const LOCAL_DESKTOP_VNC_PORT = 5900;
const TOKEN_TTL_MS = 60_000;
const TOKEN_PATTERN = /^[a-f0-9]{48}$/u;
const MAX_PAYLOAD_BYTES = 1024 * 1024;
const MAX_CONCURRENT_OBSERVERS = 4;
const PAUSE_BUFFERED_BYTES = 4 * 1024 * 1024;
const RESUME_CHECK_MS = 25;

type LocalDesktopTokenEntry = { attachment: RfbAttachment; expiresAt: number };

const localDesktopTokens = new Map<string, LocalDesktopTokenEntry>();
const localDesktopWss = new WebSocketServer({ noServer: true, maxPayload: MAX_PAYLOAD_BYTES });
let activeObserverCount = 0;

function pruneLocalDesktopTokens(nowMs: number): void {
  for (const [token, entry] of localDesktopTokens) {
    if (entry.expiresAt <= nowMs) {
      localDesktopTokens.delete(token);
    }
  }
}

/** Mints a single-use, short-lived token authorizing one upgrade to the local desktop bridge. */
export function mintLocalDesktopObserverToken(
  attachment: RfbAttachment,
  nowMs = Date.now(),
): { token: string; expiresAtMs: number } {
  pruneLocalDesktopTokens(nowMs);
  const token = crypto.randomBytes(24).toString("hex");
  const expiresAtMs = nowMs + TOKEN_TTL_MS;
  localDesktopTokens.set(token, { attachment, expiresAt: expiresAtMs });
  return { token, expiresAtMs };
}

function consumeLocalDesktopObserverToken(
  token: string,
  nowMs = Date.now(),
): LocalDesktopTokenEntry | undefined {
  pruneLocalDesktopTokens(nowMs);
  const normalized = token.trim();
  if (!TOKEN_PATTERN.test(normalized)) {
    return undefined;
  }
  const entry = localDesktopTokens.get(normalized);
  if (!entry) {
    return undefined;
  }
  localDesktopTokens.delete(normalized);
  return entry.expiresAt > nowMs ? entry : undefined;
}

function writeUnauthorized(socket: Duplex): void {
  socket.write("HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n");
  socket.destroy();
}

function writeServiceUnavailable(socket: Duplex): void {
  socket.write("HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n");
  socket.destroy();
}

function rawDataBuffer(data: RawData): Buffer {
  if (Buffer.isBuffer(data)) {
    return data;
  }
  if (Array.isArray(data)) {
    return Buffer.concat(data);
  }
  return Buffer.from(data);
}

/** Upgrades one authenticated local-desktop token into a raw bidirectional RFB stream. */
export function handleLocalDesktopObserveUpgrade(
  req: IncomingMessage,
  socket: Duplex,
  head: Buffer,
  deps: { getBufferedAmount?: (ws: WebSocket) => number } = {},
): boolean {
  const resource = new URL(req.url ?? "/", "http://127.0.0.1");
  if (resource.pathname !== LOCAL_DESKTOP_OBSERVE_PATH) {
    return false;
  }
  const token = resource.searchParams.get("token") ?? "";
  const entry = consumeLocalDesktopObserverToken(token);
  if (!entry) {
    writeUnauthorized(socket);
    return true;
  }
  if (activeObserverCount >= MAX_CONCURRENT_OBSERVERS) {
    writeServiceUnavailable(socket);
    return true;
  }
  localDesktopWss.handleUpgrade(req, socket, head, (ws) => {
    activeObserverCount += 1;
    const desktopSocket = connectRfbAttachment(entry.attachment);
    let closed = false;
    let resumeTimer: ReturnType<typeof setInterval> | undefined;

    const closeBoth = (code: number, reason: string) => {
      if (closed) {
        return;
      }
      closed = true;
      activeObserverCount -= 1;
      clearInterval(resumeTimer);
      resumeTimer = undefined;
      desktopSocket.destroy();
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        ws.close(code, reason);
      }
    };

    ws.on("message", (data, isBinary) => {
      if (!isBinary || closed) {
        return;
      }
      desktopSocket.write(rawDataBuffer(data));
    });
    ws.once("close", () => closeBoth(1000, "local desktop observer closed"));
    ws.once("error", () => closeBoth(1011, "local desktop observer failed"));
    desktopSocket.on("data", (chunk) => {
      if (closed || ws.readyState !== WebSocket.OPEN) {
        return;
      }
      ws.send(chunk, { binary: true });
      const bufferedAmount = () => deps.getBufferedAmount?.(ws) ?? ws.bufferedAmount;
      if (bufferedAmount() <= PAUSE_BUFFERED_BYTES || resumeTimer) {
        return;
      }
      desktopSocket.pause();
      resumeTimer = setInterval(() => {
        if (bufferedAmount() <= PAUSE_BUFFERED_BYTES) {
          clearInterval(resumeTimer);
          resumeTimer = undefined;
          desktopSocket.resume();
        }
      }, RESUME_CHECK_MS);
      resumeTimer.unref?.();
    });
    desktopSocket.once("close", () => closeBoth(1000, "local desktop stream closed"));
    desktopSocket.once("error", () => closeBoth(1011, "local desktop stream failed"));
  });
  return true;
}
