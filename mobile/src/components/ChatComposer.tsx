import { memo } from "react";
import {
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

type ChatComposerProps = {
  value: string;
  onChangeText: (value: string) => void;
  onSend: () => void;
  disabled?: boolean;
};

function ChatComposerInner({
  value,
  onChangeText,
  onSend,
  disabled = false,
}: ChatComposerProps) {
  return (
    <View style={styles.wrap}>
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder="Type your next instruction..."
        placeholderTextColor="#6f8a9e"
        style={styles.input}
        multiline
        editable={!disabled}
      />
      <Pressable
        onPress={onSend}
        disabled={disabled}
        style={({ pressed }) => [
          styles.button,
          disabled && styles.buttonDisabled,
          pressed && !disabled && styles.buttonPressed,
        ]}
      >
        <Text style={styles.buttonText}>Send</Text>
      </Pressable>
    </View>
  );
}

export const ChatComposer = memo(ChatComposerInner);

const styles = StyleSheet.create({
  wrap: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: 10,
    paddingHorizontal: 14,
    paddingBottom: 14,
    paddingTop: 10,
  },
  input: {
    flex: 1,
    minHeight: 54,
    maxHeight: 112,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "rgba(109,220,255,0.18)",
    backgroundColor: "rgba(3,11,22,0.9)",
    color: "#ecfbff",
    fontSize: 15,
    lineHeight: 20,
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  button: {
    minWidth: 84,
    height: 54,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#ffab63",
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  buttonPressed: {
    transform: [{ scale: 0.98 }],
  },
  buttonText: {
    color: "#09121d",
    fontSize: 13,
    fontWeight: "800",
    letterSpacing: 1.2,
    textTransform: "uppercase",
  },
});
