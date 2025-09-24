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
  ts: string;
  rssi: number;
  uptime_s: number;
  power: {
    volts: number;
    amps: number;
    watts: number;
    soc_pct: number;
  };
  weight_g: number;
  motion?: boolean;
  temperature_c?: number;
  humidity_pct?: number;
}
