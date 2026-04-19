import { useEffect, useMemo, useRef, useState } from "react";
import {
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
} from "react-native";
import { LinearGradient } from "expo-linear-gradient";

import { AssistantOrb } from "./src/components/AssistantOrb";
import { ChatComposer } from "./src/components/ChatComposer";
import { MessageBubble } from "./src/components/MessageBubble";
import { useJarvisStore } from "./src/store/useJarvisStore";

export default function App() {
  const messages = useJarvisStore((state) => state.messages);
  const phase = useJarvisStore((state) => state.phase);
  const draft = useJarvisStore((state) => state.draft);
  const hasStarted = useJarvisStore((state) => state.hasStarted);
  const isBooting = useJarvisStore((state) => state.isBooting);
  const backendStatus = useJarvisStore((state) => state.backendStatus);
  const setDraft = useJarvisStore((state) => state.setDraft);
  const startAssistant = useJarvisStore((state) => state.startAssistant);
  const submitPrompt = useJarvisStore((state) => state.submitPrompt);

  const [panelExpanded, setPanelExpanded] = useState(false);
  const listRef = useRef<FlatList>(null);
  const stickToBottomRef = useRef(true);
  const data = useMemo(() => messages, [messages]);

  useEffect(() => {
    if (hasStarted) {
      setPanelExpanded(true);
    }
  }, [hasStarted]);

  const scrollToEnd = () => {
    if (stickToBottomRef.current) {
      requestAnimationFrame(() => {
        listRef.current?.scrollToEnd({ animated: true });
      });
    }
  };

  const handleScroll = (event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const { contentOffset, contentSize, layoutMeasurement } = event.nativeEvent;
    const distanceFromBottom =
      contentSize.height - contentOffset.y - layoutMeasurement.height;
    stickToBottomRef.current = distanceFromBottom < 40;
  };

  const panelHeightStyle = hasStarted
    ? panelExpanded
      ? styles.panelOpen
      : styles.panelCollapsed
    : styles.panelLaunch;

  return (
    <LinearGradient
      colors={["#020611", "#050c18", "#081223"]}
      start={{ x: 0.12, y: 0 }}
      end={{ x: 0.88, y: 1 }}
      style={styles.background}
    >
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.stage}>
          <View style={styles.noiseGrid} />

          <View style={styles.signalWhisper}>
            <View style={[styles.phaseDot, phaseStyles[phase]]} />
            <Text style={styles.signalText}>{phase}</Text>
            <Text style={styles.signalDivider}>/</Text>
            <Text style={styles.signalText}>{backendStatus}</Text>
          </View>

          <View style={styles.orbStage}>
            <AssistantOrb phase={phase} />
          </View>

          <KeyboardAvoidingView
            style={styles.overlay}
            behavior={Platform.OS === "ios" ? "padding" : undefined}
          >
            <View style={[styles.panel, panelHeightStyle]}>
              <LinearGradient
                colors={["rgba(6,14,28,0.88)", "rgba(5,12,24,0.97)"]}
                start={{ x: 0, y: 0 }}
                end={{ x: 0.9, y: 1 }}
                style={styles.panelGradient}
              >
                <View style={styles.panelHeader}>
                  <Pressable
                    accessibilityRole="button"
                    onPress={() => setPanelExpanded((value) => !value)}
                    style={({ pressed }) => [
                      styles.handleButton,
                      pressed && styles.handleButtonPressed,
                    ]}
                  >
                    <View style={styles.handleBar} />
                    <Text style={styles.handleLabel}>
                      {hasStarted
                        ? panelExpanded
                          ? "conversation"
                          : "open chat"
                        : "initialize"}
                    </Text>
                  </Pressable>

                  {hasStarted && messages.length > 0 ? (
                    <Text style={styles.panelMeta}>
                      {messages.length} transmission
                      {messages.length > 1 ? "s" : ""}
                    </Text>
                  ) : null}
                </View>

                {!hasStarted ? (
                  <View style={styles.launcherState}>
                    <Pressable
                      accessibilityRole="button"
                      style={({ pressed }) => [
                        styles.launchButton,
                        pressed && styles.launchButtonPressed,
                      ]}
                      onPress={() => void startAssistant()}
                    >
                      <View style={styles.launchOuterRing} />
                      <View style={styles.launchCore} />
                    </Pressable>
                    <Text style={styles.launchEyebrow}>stand by</Text>
                    <Text style={styles.launchText}>
                      Tap to open the channel and receive your briefing.
                    </Text>
                  </View>
                ) : (
                  <>
                    {panelExpanded ? (
                      <FlatList
                        ref={listRef}
                        data={data}
                        keyExtractor={(item) => item.id}
                        renderItem={({ item }) => (
                          <MessageBubble message={item} />
                        )}
                        style={styles.chatList}
                        contentContainerStyle={styles.chatContent}
                        onScroll={handleScroll}
                        onContentSizeChange={scrollToEnd}
                        keyboardShouldPersistTaps="handled"
                        showsVerticalScrollIndicator={false}
                      />
                    ) : messages.length > 0 ? (
                      <View style={styles.previewState}>
                        <Text style={styles.previewLabel}>Latest response</Text>
                        <Text style={styles.previewText} numberOfLines={3}>
                          {messages[messages.length - 1]?.text}
                        </Text>
                      </View>
                    ) : (
                      <View style={styles.previewState}>
                        <Text style={styles.previewLabel}>Channel open</Text>
                        <Text style={styles.previewText}>
                          The conversation will appear here once the assistant
                          responds.
                        </Text>
                      </View>
                    )}

                    {isBooting ? (
                      <View style={styles.bootingBanner}>
                        <Text style={styles.bootingText}>
                          Preparing startup briefing...
                        </Text>
                      </View>
                    ) : null}

                    <ChatComposer
                      value={draft}
                      onChangeText={setDraft}
                      onSend={() => void submitPrompt(draft)}
                      disabled={isBooting}
                    />
                  </>
                )}
              </LinearGradient>
            </View>
          </KeyboardAvoidingView>
        </View>
      </SafeAreaView>
    </LinearGradient>
  );
}

const phaseStyles = StyleSheet.create({
  idle: { backgroundColor: "#7be3ff" },
  thinking: { backgroundColor: "#7be3ff" },
  speaking: { backgroundColor: "#ffb56e" },
  listening: { backgroundColor: "#58f0cb" },
});

const styles = StyleSheet.create({
  background: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: "transparent",
  },
  stage: {
    flex: 1,
    overflow: "hidden",
    backgroundColor: "transparent",
  },
  noiseGrid: {
    ...StyleSheet.absoluteFillObject,
    opacity: 0.1,
    borderColor: "rgba(126,210,255,0.05)",
    borderWidth: 1,
  },
  signalWhisper: {
    position: "absolute",
    top: 22,
    alignSelf: "center",
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    zIndex: 3,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: "rgba(4,9,18,0.3)",
    borderWidth: 1,
    borderColor: "rgba(109,220,255,0.08)",
  },
  phaseDot: {
    width: 7,
    height: 7,
    borderRadius: 999,
  },
  signalText: {
    color: "#b8d8e7",
    fontSize: 9,
    fontWeight: "700",
    letterSpacing: 2.2,
    textTransform: "uppercase",
  },
  signalDivider: {
    color: "rgba(184,216,231,0.36)",
    fontSize: 9,
    letterSpacing: 1.6,
  },
  orbStage: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingBottom: 68,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: "flex-end",
    paddingHorizontal: 12,
    paddingBottom: 10,
  },
  panel: {
    borderRadius: 28,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: "rgba(109,220,255,0.08)",
    shadowColor: "#000",
    shadowOpacity: 0.22,
    shadowRadius: 28,
    shadowOffset: { width: 0, height: 14 },
    elevation: 18,
  },
  panelGradient: {
    flex: 1,
  },
  panelOpen: {
    height: "40%",
  },
  panelCollapsed: {
    height: 128,
  },
  panelLaunch: {
    height: 198,
  },
  panelHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 18,
    paddingTop: 14,
    paddingBottom: 10,
  },
  handleButton: {
    alignItems: "flex-start",
    gap: 8,
  },
  handleButtonPressed: {
    opacity: 0.76,
  },
  handleBar: {
    width: 42,
    height: 4,
    borderRadius: 999,
    backgroundColor: "rgba(206,243,255,0.2)",
  },
  handleLabel: {
    color: "#7494a8",
    fontSize: 9,
    fontWeight: "700",
    letterSpacing: 2.2,
    textTransform: "uppercase",
  },
  panelMeta: {
    color: "#5f788d",
    fontSize: 9,
    letterSpacing: 1.6,
    textTransform: "uppercase",
  },
  launcherState: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 28,
  },
  launchButton: {
    width: 122,
    height: 122,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 18,
  },
  launchButtonPressed: {
    transform: [{ scale: 0.985 }],
  },
  launchOuterRing: {
    position: "absolute",
    width: 122,
    height: 122,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "rgba(104,229,255,0.18)",
    backgroundColor: "rgba(8,16,31,0.36)",
  },
  launchCore: {
    width: 38,
    height: 38,
    borderRadius: 999,
    backgroundColor: "#8fecff",
    shadowColor: "#79e6ff",
    shadowOpacity: 0.82,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 0 },
  },
  launchEyebrow: {
    color: "#6fe4ff",
    fontSize: 10,
    fontWeight: "700",
    letterSpacing: 3,
    textTransform: "uppercase",
    marginBottom: 10,
  },
  launchText: {
    color: "#94aab9",
    fontSize: 14,
    lineHeight: 20,
    textAlign: "center",
    maxWidth: 248,
  },
  chatList: {
    flex: 1,
  },
  chatContent: {
    paddingHorizontal: 18,
    paddingBottom: 12,
    gap: 12,
  },
  previewState: {
    flex: 1,
    paddingHorizontal: 18,
    justifyContent: "center",
    gap: 8,
  },
  previewLabel: {
    color: "#6bdfff",
    fontSize: 9,
    fontWeight: "700",
    letterSpacing: 2.2,
    textTransform: "uppercase",
  },
  previewText: {
    color: "#d7edf7",
    fontSize: 14,
    lineHeight: 21,
  },
  bootingBanner: {
    marginHorizontal: 18,
    marginBottom: 10,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "rgba(109,220,255,0.14)",
    backgroundColor: "rgba(6,24,44,0.72)",
    paddingHorizontal: 14,
    paddingVertical: 11,
  },
  bootingText: {
    color: "#bfe8f4",
    fontSize: 12,
    letterSpacing: 0.4,
  },
});
