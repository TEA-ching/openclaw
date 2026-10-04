import { createAgentRegistry } from "acpx/agent-registry";
import type { AcpxAgentCommand } from "./command-line.js";
import { AcpxNativeAgentsSchema, type AcpxNativeAgentId } from "./config-schema.js";
import { resolveAcpxPluginConfig } from "./config.js";

type NativeAgentDescriptor = {
  id: AcpxNativeAgentId;
  name: string;
  runtimeId: string;
};

type AcpxNativeAgentStatus = NativeAgentDescriptor & {
  installation: "installed" | "missing" | "unverified";
  enabled: boolean;
};

/**
 * Launch commands for native agents that acpx 0.19.1 has no built-in registry
 * entry for. Explicit `plugins.entries.acpx.config.agents` entries win.
 */
export const ACPX_DEFAULT_AGENT_COMMANDS: Readonly<Record<string, AcpxAgentCommand>> = {
  vibe: ["vibe-acp"],
};

/** Display names for default commands above; acpx would otherwise show the bare id. */
const ACPX_DEFAULT_AGENT_NAMES: Readonly<Record<string, string>> = { vibe: "Mistral Vibe" };

export function resolveAcpxNativeAgentName(agentId: string, registryName: string): string {
  return ACPX_DEFAULT_AGENT_NAMES[agentId] ?? registryName;
}

export function withAcpxDefaultAgentCommands(
  overrides: Readonly<Record<string, AcpxAgentCommand>> | undefined,
): Record<string, AcpxAgentCommand> {
  return { ...ACPX_DEFAULT_AGENT_COMMANDS, ...overrides };
}

export function isAcpxNativeAgentEnabled(flags: unknown, agent: AcpxNativeAgentId): boolean {
  return AcpxNativeAgentsSchema.parse(flags)?.[agent] !== false;
}

export function createAcpxAgentRegistry(rawConfig: unknown) {
  const config = resolveAcpxPluginConfig({ rawConfig });
  return createAgentRegistry({ overrides: withAcpxDefaultAgentCommands(config.agents) });
}

export function listAcpxNativeAgents(
  rawConfig: Record<string, unknown> | undefined,
  agents: readonly NativeAgentDescriptor[],
): AcpxNativeAgentStatus[] {
  const registry = createAcpxAgentRegistry(rawConfig);
  const enabled = AcpxNativeAgentsSchema.parse(rawConfig?.nativeAgents);
  return agents.map((agent): AcpxNativeAgentStatus => ({
    ...agent,
    installation: registry.inspect(agent.id)?.launch.kind ?? "unverified",
    enabled: enabled?.[agent.id] !== false,
  }));
}
