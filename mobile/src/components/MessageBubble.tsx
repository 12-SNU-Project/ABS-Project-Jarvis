import { memo } from "react";
import { StyleSheet, Text, View } from "react-native";

import type { ChatMessage } from "../lib/types";

function MessageBubbleInner({ message }: { message: ChatMessage }) {
  const isAssistant = message.role === "assistant";

  return (
    <View
      style={[
        styles.wrap,
        isAssistant ? styles.assistantWrap : styles.userWrap,
      ]}
    >
      <Text
        style={[styles.role, isAssistant ? styles.roleAssistant : styles.roleUser]}
      >
        {isAssistant ? "JARVIS" : "OPERATOR"}
      </Text>
      <Text style={[styles.text, isAssistant ? styles.assistantText : styles.userText]}>
        {message.text}
      </Text>
    </View>
  );
}

export const MessageBubble = memo(MessageBubbleInner);

const styles = StyleSheet.create({
  wrap: {
    maxWidth: "90%",
  },
  assistantWrap: {
    alignSelf: "flex-start",
    paddingRight: 22,
    paddingLeft: 2,
  },
  userWrap: {
    alignSelf: "flex-end",
    paddingHorizontal: 15,
    paddingVertical: 13,
    borderRadius: 18,
    borderTopRightRadius: 10,
    borderWidth: 1,
    borderColor: "rgba(255,179,112,0.16)",
    backgroundColor: "rgba(34,22,16,0.76)",
  },
  role: {
    marginBottom: 5,
    fontSize: 9,
    fontWeight: "700",
    letterSpacing: 2.6,
    textTransform: "uppercase",
  },
  roleAssistant: {
    color: "rgba(113,229,255,0.76)",
  },
  roleUser: {
    color: "#ffc795",
  },
  text: {
    fontSize: 15,
    lineHeight: 23,
  },
  assistantText: {
    color: "#eef8fe",
  },
  userText: {
    color: "#fff2e6",
  },
});
