import { memo } from "react";
import { StyleSheet, Text, View } from "react-native";

import type { ChatMessage } from "../lib/types";

function MessageBubbleInner({ message }: { message: ChatMessage }) {
  const isAssistant = message.role === "assistant";

  return (
    <View
      style={[
        styles.wrap,
        isAssistant ? styles.wrapAssistant : styles.wrapUser,
      ]}
    >
      <Text style={[styles.role, isAssistant ? styles.roleAssistant : styles.roleUser]}>
        {isAssistant ? "JARVIS" : "You"}
      </Text>
      <Text style={styles.text}>{message.text}</Text>
    </View>
  );
}

export const MessageBubble = memo(MessageBubbleInner);

const styles = StyleSheet.create({
  wrap: {
    maxWidth: "92%",
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderWidth: 1,
  },
  wrapAssistant: {
    alignSelf: "flex-start",
    backgroundColor: "rgba(10,18,34,0.86)",
    borderColor: "rgba(109,220,255,0.14)",
  },
  wrapUser: {
    alignSelf: "flex-end",
    backgroundColor: "rgba(18,39,65,0.92)",
    borderColor: "rgba(109,220,255,0.24)",
  },
  role: {
    marginBottom: 6,
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 1.8,
    textTransform: "uppercase",
  },
  roleAssistant: {
    color: "#6de4ff",
  },
  roleUser: {
    color: "#d3f6ff",
  },
  text: {
    color: "#edfaff",
    fontSize: 15,
    lineHeight: 21,
  },
});
