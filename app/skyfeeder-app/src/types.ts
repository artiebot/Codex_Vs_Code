export interface DiscoveryPayload {
  schema: string;
  id: string;
  fw: string;
  hw: string;
  mac: string;
  ip: string;
  capabilities: string[];
  topics: Record<string, string>;
  qos: Record<string, number>;
  ts: string;
  notes?: string;
}

export interface CommandEnvelope {
  schema: string;
  reqId: string;
  type: "led" | "camera";
  payload: Record<string, unknown>;
}

export interface AckPayload {
  schema: string;
  reqId: string;
  ok: boolean;
  code: string;
  msg: string;
  data?: Record<string, unknown>;
  ts?: string;
}

export interface TelemetryPayload {
  schema: string;
  ts_ms: number;
  firmware: {
    version: string;
    channel?: string;
  };
  power: {
    pack_v?: number;
    cell_v?: number;
    amps?: number;
    watts?: number;
    state?: number;
    bmax?: number;
    ok?: boolean;
  };
  weight_g?: number;
  weight?: {
    raw?: number;
    cal?: number;
    ok?: boolean;
  };
  led: {
    pattern?: string;
    brightness?: number;
  };
  camera: {
    status?: string;
  };
  battery?: number;
  health?: {
    uptime_ms?: number;
    last_seen_ms?: number;
    telemetry_count?: number;
    mqtt_retries?: number;
    since_last_ms?: number;
    rssi?: number;
  };
}
