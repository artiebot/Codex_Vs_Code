import { StyleSheet } from "react-native";

export const dashboardStyles = StyleSheet.create({
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
  muted: {
    color: "#64748b",
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

export type DashboardStyles = typeof dashboardStyles;
