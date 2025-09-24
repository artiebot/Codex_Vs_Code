export interface BrokerConfig {
  url: string;
  username: string;
  password: string;
  discoveryTopicFilter: string;
}

const DEFAULT_WS_URL = "ws://10.0.0.4:9001";

export const brokerConfig: BrokerConfig = {
  url: process.env.EXPO_PUBLIC_BROKER_WS_URL ?? DEFAULT_WS_URL,
  username: process.env.EXPO_PUBLIC_BROKER_USERNAME ?? "dev1",
  password: process.env.EXPO_PUBLIC_BROKER_PASSWORD ?? "dev1pass",
  discoveryTopicFilter: "skyfeeder/+/discovery",
};

export const featureFlags = {
  enableMdns: (process.env.EXPO_PUBLIC_ENABLE_MDNS ?? "0") === "1",
};
