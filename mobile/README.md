# Jarvis Mobile

Expo-based React Native adaptation of the Jarvis assistant UI.

## Run

```bash
cd mobile
npm install
npm run start
```

## Backend URL

Set `EXPO_PUBLIC_API_BASE_URL` if the backend is not reachable at the default simulator URL.

Examples:

```bash
EXPO_PUBLIC_API_BASE_URL=http://127.0.0.1:8000/api/v1 npm run start
```

```bash
EXPO_PUBLIC_API_BASE_URL=http://10.0.2.2:8000/api/v1 npm run android
```

For physical devices, point the variable at your machine's LAN IP.
