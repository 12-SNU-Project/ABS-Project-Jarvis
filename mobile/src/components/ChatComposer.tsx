import { memo } from "react";
import { Pressable, StyleSheet, Text, TextInput, View } from "react-native";

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
      <View style={styles.inputShell}>
        <TextInput
          value={value}
          onChangeText={onChangeText}
          placeholder="Issue a command..."
          placeholderTextColor="#6f8da2"
          style={styles.input}
          multiline
          editable={!disabled}
        />
      </View>
      <Pressable
        accessibilityRole="button"
        onPress={onSend}
        disabled={disabled}
        style={({ pressed }) => [
          styles.button,
          disabled && styles.buttonDisabled,
          pressed && !disabled && styles.buttonPressed,
        ]}
      >
        <Text style={styles.buttonGlyph}>↑</Text>
      </Pressable>
    </View>
  );
}

export const ChatComposer = memo(ChatComposerInner);

const styles = StyleSheet.create({
  wrap: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: 9,
    paddingHorizontal: 14,
    paddingTop: 8,
    paddingBottom: 12,
  },
  inputShell: {
    flex: 1,
    minHeight: 54,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "rgba(109,220,255,0.08)",
    backgroundColor: "rgba(3,10,20,0.82)",
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  input: {
    color: "#edf8ff",
    fontSize: 15,
    lineHeight: 20,
    minHeight: 38,
    maxHeight: 104,
    paddingVertical: 8,
  },
  button: {
    width: 52,
    height: 52,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#f6a15b",
    shadowColor: "#ff9b52",
    shadowOpacity: 0.18,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 7 },
  },
  buttonDisabled: {
    opacity: 0.45,
  },
  buttonPressed: {
    transform: [{ scale: 0.98 }],
  },
  buttonGlyph: {
    color: "#08111b",
    fontSize: 22,
    fontWeight: "800",
    lineHeight: 24,
  },
});
