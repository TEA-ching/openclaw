import { expect, test } from "vitest";
import { renderVnc } from "./view.ts";

test("renderVnc shows connecting status", () => {
  const result = renderVnc({
    connectionStatus: "connecting",
    errorMessage: null,
    clipboardText: "",
    onClipboardInput: () => {},
    onRetry: () => {},
  });
  expect(result).toBeDefined();
});

test("renderVnc shows connected status", () => {
  const result = renderVnc({
    connectionStatus: "connected",
    errorMessage: null,
    clipboardText: "",
    onClipboardInput: () => {},
    onRetry: () => {},
  });
  expect(result).toBeDefined();
});

test("renderVnc shows disconnected status with error", () => {
  const result = renderVnc({
    connectionStatus: "disconnected",
    errorMessage: "Connection lost",
    clipboardText: "",
    onClipboardInput: () => {},
    onRetry: () => {},
  });
  expect(result).toBeDefined();
});

test("renderVnc shows failed status with error", () => {
  const result = renderVnc({
    connectionStatus: "failed",
    errorMessage: "Failed to connect",
    clipboardText: "",
    onClipboardInput: () => {},
    onRetry: () => {},
  });
  expect(result).toBeDefined();
});

test("renderVnc renders received clipboard text into the textarea", async () => {
  const container = document.createElement("div");
  document.body.append(container);
  try {
    const { render } = await import("lit");
    render(
      renderVnc({
        connectionStatus: "connected",
        errorMessage: null,
        clipboardText: "hello from the remote",
        onClipboardInput: () => {},
        onRetry: () => {},
      }),
      container,
    );
    const textarea = container.querySelector<HTMLTextAreaElement>("#vnc-clipboard");
    expect(textarea?.value).toBe("hello from the remote");
  } finally {
    container.remove();
  }
});

test("renderVnc forwards clipboard textarea input to onClipboardInput", async () => {
  const container = document.createElement("div");
  document.body.append(container);
  try {
    const { render } = await import("lit");
    let received: string | null = null;
    render(
      renderVnc({
        connectionStatus: "connected",
        errorMessage: null,
        clipboardText: "",
        onClipboardInput: (text) => {
          received = text;
        },
        onRetry: () => {},
      }),
      container,
    );
    const textarea = container.querySelector<HTMLTextAreaElement>("#vnc-clipboard");
    expect(textarea).toBeTruthy();
    if (textarea) {
      textarea.value = "pasted text";
      textarea.dispatchEvent(new InputEvent("input", { bubbles: true }));
    }
    expect(received).toBe("pasted text");
  } finally {
    container.remove();
  }
});
