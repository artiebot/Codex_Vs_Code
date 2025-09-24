import "./src/shim";
import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  LogBox,
  SafeAreaView,
  StyleSheet,
  View,
  RefreshControl,
  FlatList,
  ScrollView,
} from "react-native";
import { NavigationContainer } from "@react-navigation/native";
import {
  createNativeStackNavigator,
  NativeStackScreenProps,
} from "@react-navigation/native-stack";
import {
  Provider as PaperProvider,
  Appbar,
  List,
  Text,
  ActivityIndicator,
  Chip,
  Button,
  Divider,
  Snackbar,
  MD3DarkTheme,
} from "react-native-paper";
import mqtt, { MqttClient } from "mqtt";
import { brokerConfig, featureFlags } from "./src/config";
import type {
  DiscoveryPayload,
  AckPayload,
  TelemetryPayload,
} from "./src/types";
import { useMockMdnsDevices } from "./src/mdns";

LogBox.ignoreLogs([
  "props.pointerEvents is deprecated",
  "Animated: `useNativeDriver` is not supported because the native animated module is missing. Falling back to JS-based animation.",
]);

type ConnectionState = "connecting" | "connected" | "reconnecting" | "error";

type RootStackParamList = {
  DeviceList: undefined;
  DeviceDetail: { deviceId: string };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

const theme = {
  ...MD3DarkTheme,
  colors: {
    ...MD3DarkTheme.colors,
    primary: "#2f93d8",
    background: "#0f172a",
    surface: "#111c33",
  },
};

interface DeviceEntry {
  id: string;
  payload: DiscoveryPayload;
  lastSeen: string;
  via: Array<"mqtt" | "mdns">;
}

interface AckState {
  payload: AckPayload;
  receivedAt: string;
}

interface PendingCommand {
  reqId: string;
  type: "led" | "camera";
  description: string;
  sentAt: number;
}

interface TelemetrySample {
  payload: TelemetryPayload;
  receivedAt: string;
}

interface SnackbarState {
  message: string;
  isError?: boolean;
}

interface DeviceListScreenProps
  extends NativeStackScreenProps<RootStackParamList, "DeviceList"> {
  devices: DeviceEntry[];
  telemetryByDevice: Map<string, TelemetrySample[]>;
  connectionState: ConnectionState;
  connectionLabel: string;
  error: string | null;
  refreshing: boolean;
  onRefresh: () => void;
}

interface DeviceDetailScreenProps
  extends NativeStackScreenProps<RootStackParamList, "DeviceDetail"> {
  device: DeviceEntry | undefined;
  telemetry: TelemetrySample[] | undefined;
  ack: AckState | undefined;
  pending: PendingCommand | undefined;
  onSendLed: (pattern: "heartbeat" | "blink" | "off") => void;
  onSendCamera: () => void;
  connectionState: ConnectionState;
}

export default function App(): JSX.Element {
  const clientRef = useRef<MqttClient | null>(null);
  const [mqttDevices, setMqttDevices] = useState<Map<string, DeviceEntry>>(new Map());
  const [connectionState, setConnectionState] = useState<ConnectionState>("connecting");
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [acks, setAcks] = useState<Map<string, AckState>>(new Map());
  const [pendingCommands, setPendingCommands] = useState<Map<string, PendingCommand>>(new Map());
  const [telemetry, setTelemetry] = useState<Map<string, TelemetrySample[]>>(new Map());
  const [snackbar, setSnackbar] = useState<SnackbarState | null>(null);
  const mdnsDevices = useMockMdnsDevices(featureFlags.enableMdns);

  const handleDiscovery = useCallback((payload: DiscoveryPayload) => {
    if (!payload?.id) {
      return;
    }
    setMqttDevices((prev) => {
      const next = new Map(prev);
      next.set(payload.id, {
        id: payload.id,
        payload,
        lastSeen: new Date().toISOString(),
        via: ["mqtt"],
      });
      return next;
    });
  }, []);

  const handleAck = useCallback((deviceId: string, ack: AckPayload) => {
    setAcks((prev) => {
      const next = new Map(prev);
      next.set(deviceId, {
        payload: ack,
        receivedAt: new Date().toISOString(),
      });
      return next;
    });

    setPendingCommands((prev) => {
      const next = new Map(prev);
      const pending = next.get(deviceId);
      if (pending && pending.reqId === ack.reqId) {
        next.delete(deviceId);
      }
      return next;
    });

    setSnackbar({
      message: ack.ok
        ? `ACK: ${ack.msg}`
        : `ACK error (${ack.code}): ${ack.msg}`,
      isError: !ack.ok,
    });
  }, []);

  const handleTelemetry = useCallback((deviceId: string, sample: TelemetryPayload) => {
    setTelemetry((prev) => {
      const next = new Map(prev);
      const history = next.get(deviceId) ?? [];
      const upcoming = [
        { payload: sample, receivedAt: new Date().toISOString() },
        ...history,
      ].slice(0, 24);
      next.set(deviceId, upcoming);
      return next;
    });
  }, []);

  const connectClient = useCallback(() => {
    if (clientRef.current) {
      return;
    }

    const clientId = `skyfeeder-app-${Math.random().toString(16).slice(2, 10)}`;
    const client = mqtt.connect(brokerConfig.url, {
      username: brokerConfig.username,
      password: brokerConfig.password,
      reconnectPeriod: 5000,
      clean: false,
      clientId,
    });

    clientRef.current = client;

    client.on("connect", () => {
      setConnectionState("connected");
      setError(null);
      client.subscribe(brokerConfig.discoveryTopicFilter, { qos: 1 }, (err) => {
        if (err) {
          setError(`Subscribe failed: ${err.message}`);
        }
      });
      client.subscribe("skyfeeder/+/ack", { qos: 1 }, (err) => {
        if (err) {
          setError(`ACK subscribe failed: ${err.message}`);
        }
      });
      client.subscribe("skyfeeder/+/telemetry", { qos: 0 }, (err) => {
        if (err) {
          setError(`Telemetry subscribe failed: ${err.message}`);
        }
      });
    });

    client.on("reconnect", () => {
      setConnectionState("reconnecting");
      setError(null);
    });

    client.on("close", () => {
      setConnectionState((prev) => (prev === "error" ? "error" : "reconnecting"));
    });

    client.on("error", (err) => {
      setConnectionState("error");
      setError(err.message);
    });

    client.on("message", (topic, buf) => {
      const text = buf.toString();

      if (topic.endsWith("/discovery")) {
        try {
          const payload = JSON.parse(text) as DiscoveryPayload;
          handleDiscovery(payload);
        } catch (err) {
          console.warn("Invalid discovery payload", err);
        }
        return;
      }

      if (topic.endsWith("/telemetry")) {
        const segments = topic.split("/");
        const deviceId = segments[1];
        if (!deviceId) {
          return;
        }
        try {
          const payload = JSON.parse(text) as TelemetryPayload;
          handleTelemetry(deviceId, payload);
        } catch (err) {
          console.warn("Invalid telemetry payload", err);
        }
        return;
      }

      if (topic.endsWith("/ack")) {
        const segments = topic.split("/");
        const deviceId = segments[1];
        if (!deviceId) {
          return;
        }
        try {
          const ack = JSON.parse(text) as AckPayload;
          handleAck(deviceId, ack);
        } catch (err) {
          console.warn("Invalid ACK payload", err);
        }
      }
    });
  }, [handleAck, handleDiscovery, handleTelemetry]);

  useEffect(() => {
    connectClient();
    return () => {
      clientRef.current?.end(true);
      clientRef.current = null;
    };
  }, [connectClient]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    const client = clientRef.current;
    if (client?.connected) {
      client.unsubscribe(brokerConfig.discoveryTopicFilter, () => {
        client.subscribe(brokerConfig.discoveryTopicFilter, { qos: 1 });
      });
      client.unsubscribe("skyfeeder/+/ack", () => {
        client.subscribe("skyfeeder/+/ack", { qos: 1 });
      });
      client.unsubscribe("skyfeeder/+/telemetry", () => {
        client.subscribe("skyfeeder/+/telemetry", { qos: 0 });
      });
    }
    setTimeout(() => setRefreshing(false), 600);
  }, []);

  const deviceList = useMemo(() => {
    const merged = new Map(mqttDevices);

    for (const entry of mdnsDevices) {
      const existing = merged.get(entry.id);
      if (existing) {
        if (!existing.via.includes("mdns")) {
          existing.via.push("mdns");
        }
        continue;
      }

      const placeholder: DiscoveryPayload = {
        schema: "v1",
        id: entry.id,
        fw: "unknown",
        hw: "unknown",
        mac: "",
        ip: entry.host,
        capabilities: [],
        topics: {},
        qos: {},
        ts: new Date().toISOString(),
      };

      merged.set(entry.id, {
        id: entry.id,
        payload: placeholder,
        lastSeen: placeholder.ts,
        via: ["mdns"],
      });
    }

    return Array.from(merged.values()).sort((a, b) => a.id.localeCompare(b.id));
  }, [mdnsDevices, mqttDevices]);

  const connectionLabel = useMemo(() => {
    switch (connectionState) {
      case "connecting":
        return "Connecting";
      case "connected":
        return "Live";
      case "reconnecting":
        return "Reconnecting";
      case "error":
        return "Offline";
      default:
        return "";
    }
  }, [connectionState]);

  const sendCommand = useCallback(
    (deviceId: string, type: "led" | "camera", payload: Record<string, unknown>) => {
      const client = clientRef.current;
      if (!client || !client.connected) {
        setSnackbar({ message: "MQTT client not connected", isError: true });
        return;
      }

      const device = mqttDevices.get(deviceId);
      if (!device) {
        setSnackbar({ message: "Device is not available over MQTT", isError: true });
        return;
      }

      const reqId = `req-${Date.now().toString(36)}-${Math.random().toString(16).slice(2, 6)}`;
      const topic = device.payload.topics?.cmd ?? `skyfeeder/${deviceId}/cmd`;
      const envelope = {
        schema: "v1",
        reqId,
        type,
        payload,
      };

      client.publish(topic, JSON.stringify(envelope), { qos: 1 }, (publishErr) => {
        if (publishErr) {
          setSnackbar({ message: `Publish failed: ${publishErr.message}`, isError: true });
          return;
        }

        setPendingCommands((prev) => {
          const next = new Map(prev);
          const description =
            type === "led"
              ? `LED → ${(payload.pattern as string) ?? "unknown"}`
              : "Camera → snap";
          next.set(deviceId, {
            reqId,
            type,
            description,
            sentAt: Date.now(),
          });
          return next;
        });

        setSnackbar({ message: "Command sent — awaiting ACK" });
      });
    },
    [mqttDevices],
  );

  return (
    <PaperProvider theme={theme}>
      <NavigationContainer>
        <Stack.Navigator screenOptions={{ headerShown: false }}>
          <Stack.Screen name="DeviceList">
            {(props) => (
              <DeviceListScreen
                {...props}
                devices={deviceList}
                telemetryByDevice={telemetry}
                connectionState={connectionState}
                connectionLabel={connectionLabel}
                error={error}
                refreshing={refreshing}
                onRefresh={onRefresh}
              />
            )}
          </Stack.Screen>
          <Stack.Screen name="DeviceDetail">
            {(props) => {
              const { deviceId } = props.route.params;
              const device = deviceList.find((entry) => entry.id === deviceId);
              const ack = device ? acks.get(device.id) : undefined;
              const pending = device ? pendingCommands.get(device.id) : undefined;
              const deviceTelemetry = device ? telemetry.get(device.id) : undefined;
              return (
                <DeviceDetailScreen
                  {...props}
                  device={device}
                  telemetry={deviceTelemetry}
                  ack={ack}
                  pending={pending}
                  onSendLed={(pattern) => sendCommand(deviceId, "led", { pattern })}
                  onSendCamera={() => sendCommand(deviceId, "camera", { action: "snap" })}
                  connectionState={connectionState}
                />
              );
            }}
          </Stack.Screen>
        </Stack.Navigator>
      </NavigationContainer>
      <Snackbar
        visible={Boolean(snackbar)}
        onDismiss={() => setSnackbar(null)}
        duration={4000}
        style={snackbar?.isError ? styles.snackbarError : undefined}
      >
        {snackbar?.message ?? ""}
      </Snackbar>
    </PaperProvider>
  );
}

function DeviceListScreen({
  devices,
  telemetryByDevice,
  navigation,
  connectionLabel,
  connectionState,
  error,
  refreshing,
  onRefresh,
}: DeviceListScreenProps) {
  return (
    <SafeAreaView style={styles.safeArea}>
      <Appbar.Header>
        <Appbar.Content title="SkyFeeder" subtitle={`Discovery - ${connectionLabel}`} />
      </Appbar.Header>
      <View style={styles.container}>
        {error ? <Text style={styles.error}>MQTT error: {error}</Text> : null}
        {devices.length === 0 ? (
          <View style={styles.emptyState}>
            {connectionState === "connecting" || connectionState === "reconnecting" ? (
              <ActivityIndicator size="large" />
            ) : (
              <Text variant="bodyMedium" style={styles.emptyCopy}>
                No devices discovered yet. Ensure the broker exposes WebSockets and the mock publisher (Step 14D) is running.
              </Text>
            )}
          </View>
        ) : (
          <FlatList
            data={devices}
            keyExtractor={(item) => item.id}
            refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
            renderItem={({ item }) => {
              const latest = telemetryByDevice.get(item.id)?.[0];
              const socDisplay = latest
                ? ` | SoC ${latest.payload.power.soc_pct.toFixed(0)}%`
                : "";
              const weightDisplay = latest
                ? latest.payload.weight_g.toFixed(0)
                : undefined;
              return (
                <List.Item
                  title={item.id}
                  description={`fw ${item.payload.fw} | hw ${item.payload.hw}${socDisplay}`}
                  onPress={() => navigation.navigate("DeviceDetail", { deviceId: item.id })}
                  left={(props) => (
                    <List.Icon {...props} icon={item.via.includes("mqtt") ? "access-point-network" : "lan"} />
                  )}
                  right={() => (
                    <View style={styles.rightColumn}>
                      {item.payload.capabilities?.length ? (
                        <Chip compact style={styles.chip} textStyle={styles.chipText}>
                          {item.payload.capabilities.join(", ")}
                        </Chip>
                      ) : (
                        <Text style={styles.muted}>Capabilities: n/a</Text>
                      )}
                      <Chip compact style={styles.sourceChip} textStyle={styles.chipText}>
                        via {item.via.join(" + ")}
                      </Chip>
                      {weightDisplay ? (
                        <Chip compact style={styles.metricChip} textStyle={styles.chipText}>
                          {weightDisplay} g
                        </Chip>
                      ) : null}
                    </View>
                  )}
                />
              );
            }}
            ItemSeparatorComponent={() => <View style={styles.separator} />}
          />
        )}
      </View>
    </SafeAreaView>
  );
}

function DeviceDetailScreen({
  navigation,
  device,
  telemetry,
  ack,
  pending,
  onSendLed,
  onSendCamera,
  connectionState,
}: DeviceDetailScreenProps) {
  if (!device) {
    return (
      <SafeAreaView style={styles.safeArea}>
        <Appbar.Header>
          <Appbar.BackAction onPress={() => navigation.goBack()} />
          <Appbar.Content title="Device" subtitle="Unavailable" />
        </Appbar.Header>
        <View style={styles.container}>
          <View style={styles.emptyState}>
            <Text variant="bodyLarge" style={styles.emptyCopy}>
              Device not found. It may have gone offline.
            </Text>
          </View>
        </View>
      </SafeAreaView>
    );
  }

  const ackPayload = ack?.payload;
  const ackIcon = ackPayload?.ok ? "check-circle" : "alert-circle";
  const ackChipStyle = ackPayload?.ok ? styles.ackSuccess : styles.ackError;
  const latestTelemetry = telemetry?.[0];
  const telemetryHistory = telemetry?.slice(0, 5) ?? [];

  const formatIso = (iso?: string) =>
    iso ? new Date(iso).toLocaleString() : "";

  return (
    <SafeAreaView style={styles.safeArea}>
      <Appbar.Header>
        <Appbar.BackAction onPress={() => navigation.goBack()} />
        <Appbar.Content title={device.id} subtitle={`MQTT - ${connectionState}`} />
      </Appbar.Header>
      <ScrollView contentContainerStyle={styles.detailContent}>
        <View style={styles.section}>
          <Text variant="titleMedium" style={styles.sectionTitle}>
            Device overview
          </Text>
          <Text style={styles.detailLine}>Firmware: {device.payload.fw}</Text>
          <Text style={styles.detailLine}>Hardware: {device.payload.hw}</Text>
          <Text style={styles.detailLine}>MAC: {device.payload.mac || "n/a"}</Text>
          <Text style={styles.detailLine}>IP: {device.payload.ip || "n/a"}</Text>
          <Text style={styles.detailLine}>
            Topics: {device.payload.topics?.cmd ?? `skyfeeder/${device.id}/cmd`} (cmd), {" "}
            {device.payload.topics?.ack ?? `skyfeeder/${device.id}/ack`} (ack)
          </Text>
          <View style={styles.detailChips}>
            <Chip compact style={styles.sourceChip} textStyle={styles.chipText}>
              via {device.via.join(" + ")}
            </Chip>
            <Chip compact style={styles.chip} textStyle={styles.chipText}>
              {device.payload.capabilities?.length
                ? device.payload.capabilities.join(", ")
                : "Capabilities: n/a"}
            </Chip>
          </View>
        </View>

        <Divider style={styles.divider} />

        <View style={styles.section}>
          <Text variant="titleMedium" style={styles.sectionTitle}>
            Controls
          </Text>
          <Text style={styles.detailHint}>
            Commands publish to the device with QoS 1 and await an acknowledgment on {device.payload.topics?.ack ?? `skyfeeder/${device.id}/ack`}.
          </Text>
          <View style={styles.buttonRow}>
            <Button
              mode="contained"
              onPress={() => onSendLed("heartbeat")}
              style={styles.commandButton}
              disabled={Boolean(pending)}
            >
              LED Heartbeat
            </Button>
            <Button
              mode="contained"
              onPress={() => onSendLed("blink")}
              style={styles.commandButton}
              disabled={Boolean(pending)}
            >
              LED Blink
            </Button>
            <Button
              mode="outlined"
              onPress={() => onSendLed("off")}
              style={styles.commandButton}
              disabled={Boolean(pending)}
            >
              LED Off
            </Button>
          </View>
          <View style={styles.buttonRow}>
            <Button
              mode="contained"
              onPress={onSendCamera}
              style={styles.commandButton}
              disabled={Boolean(pending)}
            >
              Camera Snap
            </Button>
          </View>
          {pending ? (
            <Chip icon="clock-outline" style={styles.pendingChip} textStyle={styles.chipText}>
              Waiting for ACK — {pending.description}
            </Chip>
          ) : null}
          {ackPayload ? (
            <Chip
              icon={ackIcon}
              style={[styles.statusChip, ackChipStyle]}
              textStyle={styles.chipText}
            >
              {ackPayload.ok ? "ACK OK" : "ACK Error"}: {ackPayload.msg}
            </Chip>
          ) : null}
          {ack?.receivedAt ? (
            <Text style={styles.detailHint}>
              Last ACK received at {formatIso(ack.receivedAt)} ({ackPayload?.code})
            </Text>
          ) : null}
        </View>

        <Divider style={styles.divider} />

        <View style={styles.section}>
          <Text variant="titleMedium" style={styles.sectionTitle}>
            Telemetry
          </Text>
          {latestTelemetry ? (
            <View style={styles.metricGrid}>
              <View style={styles.metricCard}>
                <Text style={styles.metricLabel}>Voltage</Text>
                <Text style={styles.metricValue}>
                  {latestTelemetry.payload.power.volts.toFixed(2)} V
                </Text>
              </View>
              <View style={styles.metricCard}>
                <Text style={styles.metricLabel}>Current</Text>
                <Text style={styles.metricValue}>
                  {latestTelemetry.payload.power.amps.toFixed(2)} A
                </Text>
              </View>
              <View style={styles.metricCard}>
                <Text style={styles.metricLabel}>Power</Text>
                <Text style={styles.metricValue}>
                  {latestTelemetry.payload.power.watts.toFixed(2)} W
                </Text>
              </View>
              <View style={styles.metricCard}>
                <Text style={styles.metricLabel}>State of Charge</Text>
                <Text style={styles.metricValue}>
                  {latestTelemetry.payload.power.soc_pct.toFixed(0)}%
                </Text>
              </View>
              <View style={styles.metricCard}>
                <Text style={styles.metricLabel}>Weight</Text>
                <Text style={styles.metricValue}>
                  {latestTelemetry.payload.weight_g.toFixed(1)} g
                </Text>
              </View>
              <View style={styles.metricCard}>
                <Text style={styles.metricLabel}>RSSI</Text>
                <Text style={styles.metricValue}>{latestTelemetry.payload.rssi} dBm</Text>
              </View>
            </View>
          ) : (
            <Text style={styles.detailHint}>No telemetry received yet.</Text>
          )}

          {telemetryHistory.length > 1 ? (
            <View style={styles.historyList}>
              {telemetryHistory.map((sample) => (
                <Text key={sample.receivedAt} style={styles.historyLine}>
                  {new Date(sample.receivedAt).toLocaleTimeString()} — {sample.payload.power.watts.toFixed(2)} W, {" "}
                  {sample.payload.weight_g.toFixed(1)} g, RSSI {sample.payload.rssi} dBm
                </Text>
              ))}
            </View>
          ) : null}

          {latestTelemetry ? (
            <Text style={styles.detailHint}>
              Last telemetry at {formatIso(latestTelemetry.receivedAt)} (uptime {latestTelemetry.payload.uptime_s}s)
            </Text>
          ) : null}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: "#0f172a",
  },
  container: {
    flex: 1,
  },
  detailContent: {
    paddingHorizontal: 16,
    paddingBottom: 32,
    gap: 24,
  },
  section: {
    gap: 12,
  },
  sectionTitle: {
    color: "#e2e8f0",
  },
  detailLine: {
    color: "#cbd5f5",
    fontSize: 15,
  },
  detailHint: {
    color: "#94a3b8",
    fontSize: 13,
  },
  detailChips: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  emptyState: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 32,
  },
  emptyCopy: {
    color: "#94a3b8",
    textAlign: "center",
  },
  separator: {
    height: 1,
    backgroundColor: "#1e293b",
    marginHorizontal: 12,
  },
  error: {
    color: "#f97316",
    padding: 12,
    textAlign: "center",
  },
  rightColumn: {
    minWidth: 160,
    alignItems: "flex-end",
    gap: 6,
  },
  chip: {
    backgroundColor: "#1d4ed8",
  },
  sourceChip: {
    backgroundColor: "#2563eb",
  },
  metricChip: {
    backgroundColor: "#0f172a",
    borderColor: "#1d4ed8",
    borderWidth: 1,
  },
  chipText: {
    color: "#eff6ff",
  },
  pendingChip: {
    backgroundColor: "#334155",
  },
  statusChip: {
    backgroundColor: "#0f172a",
    borderWidth: 1,
    borderColor: "#1e293b",
  },
  ackSuccess: {
    borderColor: "#22c55e",
  },
  ackError: {
    borderColor: "#f97316",
  },
  buttonRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
  },
  commandButton: {
    flexGrow: 1,
  },
  divider: {
    backgroundColor: "#1e293b",
  },
  snackbarError: {
    backgroundColor: "#b91c1c",
  },
  metricGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
  },
  metricCard: {
    flexBasis: "48%",
    backgroundColor: "#111c33",
    borderRadius: 12,
    paddingVertical: 12,
    paddingHorizontal: 16,
    gap: 4,
  },
  metricLabel: {
    color: "#94a3b8",
    fontSize: 13,
    textTransform: "uppercase",
  },
  metricValue: {
    color: "#e2e8f0",
    fontSize: 18,
    fontWeight: "600",
  },
  historyList: {
    gap: 6,
  },
  historyLine: {
    color: "#cbd5f5",
    fontSize: 13,
  },
});
