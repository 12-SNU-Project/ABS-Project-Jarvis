import { Platform } from "react-native";

const envBase = process.env.EXPO_PUBLIC_API_BASE_URL?.trim();

const fallbackBase =
  Platform.OS === "android"
    ? "http://10.0.2.2:8000/api/v1"
    : "http://127.0.0.1:8000/api/v1";

export const API_BASE_URL = (envBase && envBase.length > 0
  ? envBase
  : fallbackBase
).replace(/\/$/, "");
