import { useMemo, useRef } from "react";
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

  const listRef = useRef<FlatList>(null);
  const stickToBottomRef = useRef(true);

  const data = useMemo(() => messages, [messages]);

  const scrollToEnd = () => {
    if (stickToBottomRef.current) {
      requestAnimationFrame(() => {
        listRef.current?.scrollToEnd({ animated: true });
      });
    }
  };

  const handleScroll = (
    event: NativeSyntheticEvent<NativeScrollEvent>,
  ) => {
    const { contentOffset, contentSize, layoutMeasurement } = event.nativeEvent;
    const distanceFromBottom =
      contentSize.height - contentOffset.y - layoutMeasurement.height;
    stickToBottomRef.current = distanceFromBottom < 40;
  };

  return (
    <LinearGradient
      colors={["#06111f", "#050b16", "#020712"]}
      start={{ x: 0.1, y: 0 }}
      end={{ x: 0.85, y: 1 }}
      style={styles.background}
    >
      <SafeAreaView style={styles.safeArea}>
        <KeyboardAvoidingView
          style={styles.shell}
          behavior={Platform.OS === "ios" ? "padding" : undefined}
        >
          <View style={styles.hero}>
            <Text style={styles.masthead}>JARVIS Mobile</Text>
            <Text style={styles.subhead}>
              Backend-connected assistant console for calendar planning and
              proposal validation.
            </Text>
            <View style={styles.orbWrap}>
              <AssistantOrb phase={phase} />
            </View>
            <View style={styles.statusBar}>
              <Text style={styles.statusLabel}>Phase</Text>
              <Text style={styles.statusValue}>{phase}</Text>
              <View style={styles.statusDivider} />
              <Text style={styles.statusLabel}>Backend</Text>
              <Text style={styles.statusValue}>{backendStatus}</Text>
            </View>
          </View>

          <View style={styles.chatPanel}>
            {!hasStarted ? (
              <View style={styles.launcherState}>
                <Pressable
                  style={({ pressed }) => [
                    styles.launchButton,
                    pressed && styles.launchButtonPressed,
                  ]}
                  onPress={() => void startAssistant()}
                >
                  <View style={styles.launchCore} />
                </Pressable>
                <Text style={styles.launchText}>
                  Start the assistant to receive your briefing and begin issuing
                  commands.
                </Text>
              </View>
            ) : (
              <>
                <FlatList
                  ref={listRef}
                  data={data}
                  keyExtractor={(item) => item.id}
                  renderItem={({ item }) => <MessageBubble message={item} />}
                  contentContainerStyle={styles.chatContent}
                  style={styles.chatList}
                  onScroll={handleScroll}
                  onContentSizeChange={scrollToEnd}
                  keyboardShouldPersistTaps="handled"
                  showsVerticalScrollIndicator={false}
                />
                {isBooting ? (
                  <View style={styles.bootingBanner}>
                    <Text style={styles.bootingText}>
                      Preparing your startup briefing...
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
          </View>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: "transparent",
  },
  shell: {
    flex: 1,
    paddingHorizontal: 18,
    paddingBottom: 16,
    gap: 16,
  },
  hero: {
    flex: 0.45,
    alignItems: "center",
    justifyContent: "center",
    paddingTop: 12,
  },
  masthead: {
    color: "#ecfbff",
    fontSize: 13,
    fontWeight: "700",
    letterSpacing: 3.5,
    textTransform: "uppercase",
    marginBottom: 8,
  },
  subhead: {
    color: "#8ea7bb",
    fontSize: 14,
    lineHeight: 20,
    textAlign: "center",
    marginBottom: 18,
    maxWidth: 320,
  },
  orbWrap: {
    width: "100%",
    alignItems: "center",
    justifyContent: "center",
    flex: 1,
  },
  statusBar: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "rgba(108,220,255,0.18)",
    backgroundColor: "rgba(4,12,24,0.78)",
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  statusLabel: {
    color: "#7d9cb0",
    fontSize: 11,
    letterSpacing: 1.6,
    textTransform: "uppercase",
  },
  statusValue: {
    color: "#dffcff",
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 1.2,
    textTransform: "uppercase",
  },
  statusDivider: {
    width: 1,
    height: 12,
    backgroundColor: "rgba(108,220,255,0.18)",
    marginHorizontal: 2,
  },
  chatPanel: {
    flex: 0.55,
    borderRadius: 26,
    borderWidth: 1,
    borderColor: "rgba(108,220,255,0.18)",
    backgroundColor: "rgba(5,12,23,0.88)",
    overflow: "hidden",
    shadowColor: "#000",
    shadowOpacity: 0.28,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 10 },
    elevation: 18,
  },
  launcherState: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 28,
    gap: 18,
  },
  launchButton: {
    width: 112,
    height: 112,
    borderRadius: 56,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    borderColor: "rgba(109,220,255,0.26)",
    backgroundColor: "rgba(5,18,34,0.96)",
    shadowColor: "#59d8ff",
    shadowOpacity: 0.16,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 10 },
    elevation: 12,
  },
  launchButtonPressed: {
    transform: [{ scale: 0.98 }],
  },
  launchCore: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: "#8de9ff",
    shadowColor: "#7fe4ff",
    shadowOpacity: 0.75,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 0 },
  },
  launchText: {
    color: "#b9cad8",
    fontSize: 14,
    lineHeight: 20,
    textAlign: "center",
    maxWidth: 260,
  },
  chatList: {
    flex: 1,
  },
  chatContent: {
    paddingHorizontal: 14,
    paddingTop: 18,
    paddingBottom: 10,
    gap: 12,
  },
  bootingBanner: {
    marginHorizontal: 14,
    marginBottom: 10,
    borderRadius: 14,
    backgroundColor: "rgba(11,27,48,0.72)",
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  bootingText: {
    color: "#8adff7",
    fontSize: 13,
  },
});
