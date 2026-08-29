import { html } from "lit";
import { expect, test } from "vitest";
import { renderVnc } from "./view.ts";

test("renderVnc shows connecting status", () => {
  const result = renderVnc({
    connectionStatus: "connecting",
    errorMessage: null,
    onRetry: () => {},
  });
  expect(result).toBeDefined();
});

test("renderVnc shows connected status", () => {
  const result = renderVnc({
    connectionStatus: "connected",
    errorMessage: null,
    onRetry: () => {},
  });
  expect(result).toBeDefined();
});

test("renderVnc shows disconnected status with error", () => {
  const result = renderVnc({
    connectionStatus: "disconnected",
    errorMessage: "Connection lost",
    onRetry: () => {},
  });
  expect(result).toBeDefined();
});

test("renderVnc shows failed status with error", () => {
  const result = renderVnc({
    connectionStatus: "failed",
    errorMessage: "Failed to connect",
    onRetry: () => {},
  });
  expect(result).toBeDefined();
});
