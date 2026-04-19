import { memo, useEffect, useMemo, useRef } from "react";
import {
  Animated,
  Easing,
  StyleSheet,
  View,
} from "react-native";
import Svg, { Circle } from "react-native-svg";

type AssistantPhase = "idle" | "thinking" | "speaking" | "listening";

type OrbPoint = {
  id: number;
  x: number;
  y: number;
  r: number;
  opacity: number;
};

const SIZE = 280;
const CENTER = SIZE / 2;

function generatePoints(count: number): OrbPoint[] {
  return Array.from({ length: count }, (_, index) => {
    const t = index / count;
    const angle = t * Math.PI * 2 * 7;
    const radius = 22 + (index % 17) * 5.8;
    return {
      id: index,
      x: CENTER + Math.cos(angle) * radius,
      y: CENTER + Math.sin(angle) * radius,
      r: 0.8 + (index % 5) * 0.34,
      opacity: 0.16 + ((index * 17) % 12) / 18,
    };
  });
}

function paletteForPhase(phase: AssistantPhase) {
  if (phase === "speaking") {
    return {
      core: "#ffd09f",
      accent: "#ff8e62",
      halo: "rgba(255, 142, 98, 0.28)",
    };
  }

  if (phase === "listening") {
    return {
      core: "#87ffd9",
      accent: "#4af2c5",
      halo: "rgba(74, 242, 197, 0.24)",
    };
  }

  return {
    core: "#8cecff",
    accent: "#4bd8ff",
    halo: "rgba(75, 216, 255, 0.24)",
  };
}

function AssistantOrbInner({ phase }: { phase: AssistantPhase }) {
  const points = useMemo(() => generatePoints(180), []);
  const pulse = useRef(new Animated.Value(0)).current;
  const float = useRef(new Animated.Value(0)).current;
  const spin = useRef(new Animated.Value(0)).current;
  const halo = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    pulse.stopAnimation();
    float.stopAnimation();
    spin.stopAnimation();
    halo.stopAnimation();

    const config =
      phase === "speaking"
        ? { pulseMs: 1650, floatMs: 1250, spinMs: 12000, scale: 1.06, float: 8, halo: 1 }
        : phase === "thinking"
          ? { pulseMs: 2200, floatMs: 1800, spinMs: 18000, scale: 1.03, float: 6, halo: 0.72 }
          : phase === "listening"
            ? { pulseMs: 1400, floatMs: 1350, spinMs: 15000, scale: 1.045, float: 5, halo: 0.85 }
            : { pulseMs: 2600, floatMs: 2200, spinMs: 24000, scale: 1.015, float: 4, halo: 0.5 };

    Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {
          toValue: 1,
          duration: config.pulseMs,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.timing(pulse, {
          toValue: 0,
          duration: config.pulseMs,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
      ]),
    ).start();

    Animated.loop(
      Animated.sequence([
        Animated.timing(float, {
          toValue: 1,
          duration: config.floatMs,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true,
        }),
        Animated.timing(float, {
          toValue: 0,
          duration: config.floatMs,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true,
        }),
      ]),
    ).start();

    Animated.loop(
      Animated.timing(spin, {
        toValue: 1,
        duration: config.spinMs,
        easing: Easing.linear,
        useNativeDriver: true,
      }),
    ).start();

    Animated.loop(
      Animated.sequence([
        Animated.timing(halo, {
          toValue: config.halo,
          duration: config.pulseMs,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.timing(halo, {
          toValue: config.halo * 0.55,
          duration: config.pulseMs,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
      ]),
    ).start();
  }, [float, halo, phase, pulse, spin]);

  const palette = paletteForPhase(phase);
  const scale = pulse.interpolate({
    inputRange: [0, 1],
    outputRange: [0.98, phase === "speaking" ? 1.07 : 1.03],
  });
  const translateY = float.interpolate({
    inputRange: [0, 1],
    outputRange: [0, phase === "speaking" ? -8 : -5],
  });
  const rotate = spin.interpolate({
    inputRange: [0, 1],
    outputRange: ["0deg", phase === "speaking" ? "24deg" : "12deg"],
  });

  return (
    <View style={styles.wrap}>
      <Animated.View
        style={[
          styles.halo,
          {
            backgroundColor: palette.halo,
            opacity: halo,
            transform: [{ scale }],
          },
        ]}
      />
      <Animated.View
        style={[
          styles.orb,
          {
            transform: [{ translateY }, { scale }, { rotate }],
          },
        ]}
      >
        <Svg width={SIZE} height={SIZE}>
          {points.map((point) => (
            <Circle
              key={point.id}
              cx={point.x}
              cy={point.y}
              r={point.r}
              fill={point.id % 7 === 0 ? palette.accent : palette.core}
              opacity={point.opacity}
            />
          ))}
          <Circle cx={CENTER} cy={CENTER} r={24} fill={palette.core} opacity={0.25} />
          <Circle cx={CENTER} cy={CENTER} r={10} fill={palette.accent} opacity={0.95} />
        </Svg>
      </Animated.View>
    </View>
  );
}

export const AssistantOrb = memo(AssistantOrbInner);

const styles = StyleSheet.create({
  wrap: {
    width: SIZE,
    height: SIZE,
    alignItems: "center",
    justifyContent: "center",
  },
  halo: {
    position: "absolute",
    width: SIZE * 0.78,
    height: SIZE * 0.78,
    borderRadius: SIZE,
    shadowColor: "#67dcff",
    shadowOpacity: 0.32,
    shadowRadius: 28,
    shadowOffset: { width: 0, height: 0 },
  },
  orb: {
    width: SIZE,
    height: SIZE,
    alignItems: "center",
    justifyContent: "center",
  },
});
