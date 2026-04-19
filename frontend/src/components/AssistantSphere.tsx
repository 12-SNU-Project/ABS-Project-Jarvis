import { memo, useEffect, useMemo, useRef } from "react";

type AssistantPhase = "idle" | "thinking" | "speaking" | "listening";

type SpherePoint = {
  id: number;
  x: number;
  y: number;
  z: number;
  wave: number;
};

type AmbientParticle = {
  id: number;
  x: number;
  y: number;
  radius: number;
  opacity: number;
};

type RGB = readonly [number, number, number];
type RenderPointState = {
  x: number;
  y: number;
  radius: number;
  opacity: number;
  depth: number;
};
type Palette = {
  core: RGB;
  accent: RGB;
  ambient: RGB;
};
type SphereComplexity = {
  pointCount: number;
  ambientCount: number;
};

const VIEWBOX_SIZE = 720;
const HALF_VIEWBOX = VIEWBOX_SIZE / 2;
const BASE_RADIUS = 190;
const CAMERA_DISTANCE = 580;

function generateSpherePoints(count: number): SpherePoint[] {
  const points: SpherePoint[] = [];
  const goldenAngle = Math.PI * (3 - Math.sqrt(5));

  for (let index = 0; index < count; index += 1) {
    const t = count === 1 ? 0 : index / (count - 1);
    const y = 1 - t * 2;
    const radial = Math.sqrt(1 - y * y);
    const theta = goldenAngle * index;

    points.push({
      id: index,
      x: Math.cos(theta) * radial,
      y,
      z: Math.sin(theta) * radial,
      wave: (1 - y) / 2,
    });
  }

  return points;
}

function generateAmbientParticles(count: number): AmbientParticle[] {
  const particles: AmbientParticle[] = [];

  for (let index = 0; index < count; index += 1) {
    particles.push({
      id: index,
      x: 100 + ((index * 83) % 520),
      y: 90 + ((index * 137) % 520),
      radius: 0.8 + ((index * 17) % 8) / 5,
      opacity: 0.08 + ((index * 19) % 10) / 84,
    });
  }

  return particles;
}

function rotatePoint(
  point: SpherePoint,
  angleX: number,
  angleY: number,
  angleZ: number,
) {
  const sinX = Math.sin(angleX);
  const cosX = Math.cos(angleX);
  const sinY = Math.sin(angleY);
  const cosY = Math.cos(angleY);
  const sinZ = Math.sin(angleZ);
  const cosZ = Math.cos(angleZ);

  let x = point.x;
  let y = point.y;
  let z = point.z;

  const y1 = y * cosX - z * sinX;
  const z1 = y * sinX + z * cosX;
  y = y1;
  z = z1;

  const x2 = x * cosY + z * sinY;
  const z2 = -x * sinY + z * cosY;
  x = x2;
  z = z2;

  const x3 = x * cosZ - y * sinZ;
  const y3 = x * sinZ + y * cosZ;

  return { x: x3, y: y3, z };
}

function rgba(rgb: RGB, alpha: number): string {
  return `rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, ${alpha})`;
}

function lerp(start: number, end: number, amount: number): number {
  return start + (end - start) * amount;
}

function mixRgb(start: RGB, end: RGB, amount: number): RGB {
  return [
    lerp(start[0], end[0], amount),
    lerp(start[1], end[1], amount),
    lerp(start[2], end[2], amount),
  ];
}

function colorsForPhase(phase: AssistantPhase): Palette {
  if (phase === "speaking") {
    return {
      core: [255, 182, 106] as const,
      accent: [255, 157, 68] as const,
      ambient: [255, 181, 109] as const,
    };
  }

  if (phase === "listening") {
    return {
      core: [120, 255, 211] as const,
      accent: [46, 247, 197] as const,
      ambient: [89, 255, 216] as const,
    };
  }

  return {
    core: [124, 232, 255] as const,
    accent: [73, 215, 255] as const,
    ambient: [103, 216, 255] as const,
  };
}

function resolvePointTarget(
  point: SpherePoint,
  phase: AssistantPhase,
  time: number,
): RenderPointState {
  let angleX = 0;
  let angleY = 0;
  let angleZ = 0;
  let radialBreathe = 1;
  let yOffset = 0;
  let energy = 0;

  if (phase === "thinking") {
    angleX = -0.24 + Math.sin(time * 0.7) * 0.05;
    angleY = time * 0.48;
    angleZ = Math.sin(time * 0.2) * 0.03;
    energy = Math.max(0, Math.sin(time * 4.6 - point.wave * 7.4));
    radialBreathe = 1 + energy * 0.06;
    yOffset = -energy * 12;
  } else if (phase === "speaking") {
    angleX = Math.sin(time * 1.2) * 0.25;
    angleY = time * 0.95;
    angleZ = Math.cos(time * 0.75) * 0.22;
    const turbulence =
      Math.sin(time * 5 + point.wave * 9) * 0.5 +
      Math.cos(time * 3.4 + point.z * 6) * 0.5;
    energy = (turbulence + 1) / 2;
    radialBreathe = 1 + energy * 0.18;
    yOffset = Math.sin(time * 4.2 + point.wave * 8) * 10;
  } else if (phase === "listening") {
    angleX = -0.1 + Math.sin(time * 0.42) * 0.03;
    angleY = time * 0.34;
    angleZ = Math.sin(time * 0.18) * 0.02;
    energy = Math.max(0, Math.sin(time * 5.8 - point.wave * 11.4));
    radialBreathe = 1 + energy * 0.1;
    yOffset = Math.sin(time * 2.1 + point.wave * 6.4) * 4;
  } else {
    angleX = -0.12 + Math.sin(time * 0.35) * 0.05;
    angleY = time * 0.22;
    angleZ = Math.cos(time * 0.3) * 0.04;
    energy = (Math.sin(time * 2 + point.wave * 8) + 1) / 2;
    radialBreathe = 1 + energy * 0.03;
    yOffset = Math.sin(time * 1.3 + point.wave * 5) * 3;
  }

  const rotated = rotatePoint(point, angleX, angleY, angleZ);
  const scaledX = rotated.x * BASE_RADIUS * radialBreathe;
  const scaledY = rotated.y * BASE_RADIUS * radialBreathe + yOffset;
  const scaledZ = rotated.z * BASE_RADIUS;
  const perspective = CAMERA_DISTANCE / (CAMERA_DISTANCE - scaledZ);

  return {
    x: HALF_VIEWBOX + scaledX * perspective,
    y: HALF_VIEWBOX + scaledY * perspective,
    radius: (0.48 + (rotated.z + 1) * 0.92) * perspective,
    opacity:
      0.12 +
      ((rotated.z + 1) / 2) * 0.54 +
      (phase === "speaking" ? energy * 0.12 : energy * 0.09),
    depth: rotated.z,
  };
}

function getSphereComplexity(): SphereComplexity {
  if (typeof window === "undefined") {
    return { pointCount: 820, ambientCount: 60 };
  }

  const navigatorWithMemory = navigator as Navigator & {
    deviceMemory?: number;
  };
  const reducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)")
    .matches;
  const memory = navigatorWithMemory.deviceMemory ?? 8;
  const cores = navigator.hardwareConcurrency ?? 8;

  if (reducedMotion || memory <= 4 || cores <= 4) {
    return { pointCount: 620, ambientCount: 40 };
  }

  if (memory <= 8 || cores <= 8) {
    return { pointCount: 820, ambientCount: 56 };
  }

  return { pointCount: 960, ambientCount: 72 };
}

function AssistantSphereInner({ phase }: { phase: AssistantPhase }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const phaseRef = useRef<AssistantPhase>(phase);
  const complexity = useMemo(() => getSphereComplexity(), []);
  const points = useMemo(
    () => generateSpherePoints(complexity.pointCount),
    [complexity],
  );
  const ambientParticles = useMemo(
    () => generateAmbientParticles(complexity.ambientCount),
    [complexity],
  );

  useEffect(() => {
    phaseRef.current = phase;
  }, [phase]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) {
      return;
    }

    const context = canvas.getContext("2d");
    if (!context) {
      return;
    }

    let width = VIEWBOX_SIZE;
    let height = VIEWBOX_SIZE;
    let frame = 0;
    const start = performance.now();
    const pointStates = points.map((point) =>
      resolvePointTarget(point, phaseRef.current, 0),
    );
    const palette: Palette = colorsForPhase(phaseRef.current);

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      const nextWidth = Math.max(1, Math.floor(rect.width));
      const nextHeight = Math.max(1, Math.floor(rect.height));
      const devicePixelRatio = window.devicePixelRatio || 1;

      width = nextWidth;
      height = nextHeight;
      canvas.width = Math.floor(nextWidth * devicePixelRatio);
      canvas.height = Math.floor(nextHeight * devicePixelRatio);
      context.setTransform(
        canvas.width / VIEWBOX_SIZE,
        0,
        0,
        canvas.height / VIEWBOX_SIZE,
        0,
        0,
      );
    };

    resize();
    const resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(canvas);

    const drawGlow = (
      radius: number,
      innerColor: string,
      outerColor: string,
      opacity: number,
    ) => {
      const gradient = context.createRadialGradient(
        HALF_VIEWBOX,
        HALF_VIEWBOX,
        0,
        HALF_VIEWBOX,
        HALF_VIEWBOX,
        radius,
      );
      gradient.addColorStop(0, innerColor);
      gradient.addColorStop(0.68, outerColor);
      gradient.addColorStop(1, "rgba(11, 24, 49, 0)");
      context.globalAlpha = opacity;
      context.fillStyle = gradient;
      context.beginPath();
      context.arc(HALF_VIEWBOX, HALF_VIEWBOX, radius, 0, Math.PI * 2);
      context.fill();
    };

    const render = (now: number) => {
      const time = (now - start) / 1000;
      const activePhase = phaseRef.current;
      const targetPalette = colorsForPhase(activePhase);

      palette.core = mixRgb(palette.core, targetPalette.core, 0.1);
      palette.accent = mixRgb(palette.accent, targetPalette.accent, 0.1);
      palette.ambient = mixRgb(palette.ambient, targetPalette.ambient, 0.1);
      context.clearRect(0, 0, VIEWBOX_SIZE, VIEWBOX_SIZE);

      drawGlow(
        BASE_RADIUS * 1.55,
        rgba(palette.core, 0.18),
        rgba(palette.core, 0.02),
        1,
      );
      drawGlow(
        BASE_RADIUS * 0.92,
        rgba(palette.core, 0.5),
        rgba(palette.accent, 0.14),
        1,
      );

      for (const particle of ambientParticles) {
        context.globalAlpha = particle.opacity;
        context.fillStyle = rgba(palette.ambient, 1);
        context.beginPath();
        context.arc(particle.x, particle.y, particle.radius, 0, Math.PI * 2);
        context.fill();
      }

      const renderedPoints = points
        .map((point, index) => {
          const target = resolvePointTarget(point, activePhase, time);
          const current = pointStates[index];

          current.x = lerp(current.x, target.x, 0.16);
          current.y = lerp(current.y, target.y, 0.16);
          current.radius = lerp(current.radius, target.radius, 0.18);
          current.opacity = lerp(current.opacity, target.opacity, 0.18);
          current.depth = lerp(current.depth, target.depth, 0.14);

          return current;
        })
        .sort((left, right) => left.depth - right.depth);

      for (const point of renderedPoints) {
        context.globalAlpha = Math.min(point.opacity * 0.24, 0.18);
        context.fillStyle = rgba(palette.core, 1);
        context.beginPath();
        context.arc(point.x, point.y, point.radius * 1.4, 0, Math.PI * 2);
        context.fill();
      }

      for (const point of renderedPoints) {
        context.globalAlpha = Math.min(point.opacity, 0.9);
        context.fillStyle = rgba(palette.core, 1);
        context.beginPath();
        context.arc(point.x, point.y, point.radius, 0, Math.PI * 2);
        context.fill();
      }

      context.globalAlpha = 1;
      frame = requestAnimationFrame(render);
    };

    frame = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(frame);
      resizeObserver.disconnect();
    };
  }, [ambientParticles, points]);

  return (
    <canvas
      ref={canvasRef}
      className="assistant-sphere-svg"
      role="img"
      aria-label={`Assistant sphere in ${phase} mode`}
    />
  );
}

export const AssistantSphere = memo(AssistantSphereInner);
