type EnvMap = Record<string, string | undefined>;

function getEnvMap(): EnvMap | undefined {
  return (globalThis as { process?: { env?: EnvMap } }).process?.env;
}

export function readEnv(key: string) {
  return getEnvMap()?.[key];
}

export function isMockMode() {
  return readEnv("JARVIS_USE_MOCKS") !== "false";
}
