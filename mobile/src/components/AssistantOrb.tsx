import { Fragment, memo, useEffect, useMemo, useRef, useState } from "react";
import {
  AccessibilityInfo,
  StyleSheet,
  useWindowDimensions,
  View,
} from "react-native";
import Svg, { Circle } from "react-native-svg";

type AssistantPhase = "idle" | "thinking" | "speaking" | "listening";

type RGB = readonly [number, number, number];

type MotionProfile = {
  cool: RGB;
  accent: RGB;
  halo: string;
  core: string;
  spin: number;
  coherence: number;
  turbulence: number;
  contraction: number;
  warmth: number;
  brightness: number;
  lateral: number;
  expansion: number;
  pulseSpeed: number;
};

type ParticleSeed = {
  id: number;
  x: number;
  y: number;
  z: number;
  size: number;
  phase: number;
  orbit: number;
  sway: number;
  heat: number;
  band: number;
};

type RenderedParticle = {
  id: number;
  x: number;
  y: number;
  r: number;
  glow: number;
  opacity: number;
  fill: string;
  depth: number;
};

const TAU = Math.PI * 2;
const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));
const PARTICLE_COUNT = 360;

function clamp(value: number, min = 0, max = 1): number {
  return Math.min(max, Math.max(min, value));
}

function lerp(start: number, end: number, amount: number): number {
  return start + (end - start) * amount;
}

function pingPong(value: number): number {
  const cycle = value % 2;
  return cycle <= 1 ? cycle : 2 - cycle;
}

function blendChannel(start: RGB, end: RGB, amount: number): RGB {
  return [
    Math.round(lerp(start[0], end[0], amount)),
    Math.round(lerp(start[1], end[1], amount)),
    Math.round(lerp(start[2], end[2], amount)),
  ] as const;
}

function rgb(color: RGB): string {
  return `rgb(${color[0]}, ${color[1]}, ${color[2]})`;
}

function createProfile(phase: AssistantPhase): MotionProfile {
  if (phase === "speaking") {
    return {
      cool: [255, 210, 167],
      accent: [255, 118, 72],
      halo: "rgba(255, 120, 72, 0.34)",
      core: "rgba(255, 185, 128, 0.26)",
      spin: 0.18,
      coherence: 0.18,
      turbulence: 0.96,
      contraction: 0.08,
      warmth: 1,
      brightness: 1.08,
      lateral: 1,
      expansion: 0.92,
      pulseSpeed: 6.4,
    };
  }

  if (phase === "thinking") {
    return {
      cool: [170, 236, 255],
      accent: [83, 203, 255],
      halo: "rgba(72, 205, 255, 0.24)",
      core: "rgba(85, 176, 255, 0.18)",
      spin: 0.09,
      coherence: 1,
      turbulence: 0.18,
      contraction: 0.1,
      warmth: 0.06,
      brightness: 0.94,
      lateral: 0.2,
      expansion: 0.28,
      pulseSpeed: 2.8,
    };
  }

  if (phase === "listening") {
    return {
      cool: [143, 255, 222],
      accent: [78, 246, 201],
      halo: "rgba(86, 246, 205, 0.24)",
      core: "rgba(88, 225, 208, 0.18)",
      spin: 0.12,
      coherence: 0.44,
      turbulence: 0.22,
      contraction: 0.54,
      warmth: 0.04,
      brightness: 0.98,
      lateral: 0.26,
      expansion: 0.24,
      pulseSpeed: 3.8,
    };
  }

  return {
    cool: [156, 236, 255],
    accent: [82, 217, 255],
    halo: "rgba(83, 211, 255, 0.18)",
    core: "rgba(90, 176, 255, 0.14)",
    spin: 0.06,
    coherence: 0.22,
    turbulence: 0.08,
    contraction: 0.08,
    warmth: 0,
    brightness: 0.86,
    lateral: 0.16,
    expansion: 0.16,
    pulseSpeed: 2.1,
  };
}

function blendProfile(current: MotionProfile, target: MotionProfile, amount: number) {
  return {
    cool: blendChannel(current.cool, target.cool, amount),
    accent: blendChannel(current.accent, target.accent, amount),
    halo: target.halo,
    core: target.core,
    spin: lerp(current.spin, target.spin, amount),
    coherence: lerp(current.coherence, target.coherence, amount),
    turbulence: lerp(current.turbulence, target.turbulence, amount),
    contraction: lerp(current.contraction, target.contraction, amount),
    warmth: lerp(current.warmth, target.warmth, amount),
    brightness: lerp(current.brightness, target.brightness, amount),
    lateral: lerp(current.lateral, target.lateral, amount),
    expansion: lerp(current.expansion, target.expansion, amount),
    pulseSpeed: lerp(current.pulseSpeed, target.pulseSpeed, amount),
  };
}

function buildParticleSeeds(): ParticleSeed[] {
  return Array.from({ length: PARTICLE_COUNT }, (_, index) => {
    const y = 1 - ((index + 0.5) / PARTICLE_COUNT) * 2;
    const radius = Math.sqrt(1 - y * y);
    const theta = GOLDEN_ANGLE * index;
    return {
      id: index,
      x: Math.cos(theta) * radius,
      y,
      z: Math.sin(theta) * radius,
      size: 0.44 + ((index * 17) % 8) * 0.08,
      phase: ((index * 29) % 360) / 360,
      orbit: 0.32 + ((index * 11) % 100) / 100,
      sway: 0.6 + ((index * 23) % 100) / 100,
      heat: ((index * 19) % 100) / 100,
      band: index % 3,
    };
  });
}

function projectParticles(
  seeds: ParticleSeed[],
  time: number,
  profile: MotionProfile,
  size: number,
): RenderedParticle[] {
  const center = size / 2;
  const baseRadius = size * 0.33;
  const breath = 1 + Math.sin(time * 1.4) * 0.016;
  const thinkingFront = -1 + pingPong(time * 0.34) * 2;
  const listeningFront = Math.sin(time * 1.9) * 0.78;

  const particles = seeds.map((seed) => {
    const bandSpin = time * (profile.spin + seed.band * 0.06) + seed.phase * TAU * 0.25;
    const cosSpin = Math.cos(bandSpin);
    const sinSpin = Math.sin(bandSpin);
    const rotatedX = seed.x * cosSpin - seed.z * sinSpin;
    const rotatedZ = seed.x * sinSpin + seed.z * cosSpin;

    const speakingPulse =
      0.5 + 0.5 * Math.sin(time * profile.pulseSpeed + seed.phase * TAU * 1.6);
    const thinkingWave = Math.exp(
      -Math.pow((seed.y - thinkingFront) / 0.26, 2),
    );
    const listeningWave = Math.exp(
      -Math.pow((seed.y - listeningFront) / 0.22, 2),
    );
    const equatorBias = 1 - Math.abs(seed.y);

    const radialBoost =
      1 +
      breath * 0.04 +
      profile.coherence * thinkingWave * 0.22 +
      profile.expansion * equatorBias * speakingPulse * 0.18 -
      profile.contraction * listeningWave * 0.16;

    const turbulenceX =
      profile.turbulence *
      (Math.sin(time * (2.2 + seed.sway) + seed.phase * TAU * 2.1) * 0.1 +
        Math.cos(time * 3.8 + seed.orbit * 5) * 0.038) *
      (0.4 + equatorBias * 0.75);
    const turbulenceY =
      profile.turbulence *
      Math.cos(time * (2.7 + seed.orbit) + seed.phase * TAU) *
      0.06;
    const coherentLift =
      profile.coherence * thinkingWave * 0.2 -
      profile.contraction * listeningWave * 0.12;
    const lateralSweep =
      profile.lateral *
      Math.sin(time * 1.7 + seed.phase * TAU * 1.2) *
      0.07 *
      (0.55 + equatorBias);

    const projectedX =
      (rotatedX + turbulenceX + lateralSweep) *
      baseRadius *
      radialBoost;
    const projectedY =
      (seed.y + turbulenceY - coherentLift) *
      baseRadius *
      0.94 *
      radialBoost;
    const depth = clamp((rotatedZ + 1) / 2, 0, 1);
    const perspective = 0.66 + depth * 0.66;
    const warmth = clamp(
      profile.warmth * (0.36 + equatorBias * speakingPulse * 0.72) +
        seed.heat * 0.18 +
        thinkingWave * 0.06,
    );
    const fill = rgb(blendChannel(profile.cool, profile.accent, warmth));

    return {
      id: seed.id,
      x: center + projectedX * perspective,
      y: center + projectedY * perspective,
      r:
        seed.size *
        (0.34 + depth * 0.76) *
        (1 + thinkingWave * 0.1 + speakingPulse * profile.turbulence * 0.1),
      glow:
        seed.size *
        (1.3 + depth * 1.6) *
        (1 + thinkingWave * 0.22 + speakingPulse * profile.turbulence * 0.2),
      opacity: clamp(
        0.14 +
          depth * 0.36 +
          thinkingWave * profile.coherence * 0.18 +
          listeningWave * profile.contraction * 0.1 +
          profile.brightness * 0.05,
        0.1,
        0.78,
      ),
      fill,
      depth,
    };
  });

  particles.sort((left, right) => left.depth - right.depth);
  return particles;
}

function AssistantOrbInner({ phase }: { phase: AssistantPhase }) {
  const { width, height } = useWindowDimensions();
  const size = Math.min(width * 0.86, height * 0.48, 430);
  const particleSeeds = useMemo(() => buildParticleSeeds(), []);
  const [time, setTime] = useState(0);
  const [reduceMotion, setReduceMotion] = useState(false);
  const profileRef = useRef<MotionProfile>(createProfile(phase));
  const timeRef = useRef(0);

  useEffect(() => {
    let mounted = true;
    AccessibilityInfo.isReduceMotionEnabled()
      .then((enabled) => {
        if (mounted) {
          setReduceMotion(enabled);
        }
      })
      .catch(() => undefined);

    const subscription = AccessibilityInfo.addEventListener(
      "reduceMotionChanged",
      (enabled) => {
        setReduceMotion(enabled);
      },
    );

    return () => {
      mounted = false;
      subscription.remove();
    };
  }, []);

  useEffect(() => {
    let frameId = 0;
    let lastTime = 0;
    let lastCommit = 0;

    const tick = (timestamp: number) => {
      if (!lastTime) {
        lastTime = timestamp;
        lastCommit = timestamp;
      }

      const deltaSeconds = Math.min(42, timestamp - lastTime) / 1000;
      lastTime = timestamp;
      timeRef.current += deltaSeconds * (reduceMotion ? 0.42 : 1);
      profileRef.current = blendProfile(
        profileRef.current,
        createProfile(phase),
        reduceMotion ? 0.1 : 0.08,
      );

      const frameBudget = reduceMotion ? 80 : 33;
      if (timestamp - lastCommit >= frameBudget) {
        lastCommit = timestamp;
        setTime(timeRef.current);
      }

      frameId = requestAnimationFrame(tick);
    };

    frameId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frameId);
  }, [phase, reduceMotion]);

  const profile = profileRef.current;
  const particles = useMemo(
    () => projectParticles(particleSeeds, time, profile, size),
    [particleSeeds, profile, size, time],
  );

  return (
    <View style={[styles.wrap, { width: size, height: size }]}>
      <Svg width={size} height={size}>
        {particles.map((particle) => (
          <Fragment key={particle.id}>
            <Circle
              cx={particle.x}
              cy={particle.y}
              r={particle.glow}
              fill={particle.fill}
              opacity={particle.opacity * 0.12}
            />
            <Circle
              cx={particle.x}
              cy={particle.y}
              r={particle.r}
              fill={particle.fill}
              opacity={particle.opacity}
            />
          </Fragment>
        ))}
      </Svg>
    </View>
  );
}

export const AssistantOrb = memo(AssistantOrbInner);

const styles = StyleSheet.create({
  wrap: {
    alignItems: "center",
    justifyContent: "center",
  },
});
