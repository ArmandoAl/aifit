# Configuración de Android para Google Sign-In

## ✅ Verificaciones Completadas

1. ✅ `google-services.json` presente en `android/app/`
2. ✅ Plugin `com.google.gms.google-services` en `build.gradle.kts`
3. ✅ Permiso `INTERNET` agregado al `AndroidManifest.xml`
4. ✅ Package name: `com.example.aifit` (coincide con `google-services.json`)

## 🔑 PASO CRÍTICO: SHA-1 Fingerprint

**Google Sign-In en Android REQUIERE que registres el SHA-1 fingerprint en Firebase Console.**

### ✅ SHA-1 de tu proyecto (Debug)

**SHA-1 Debug**: `1E:A9:D6:7C:B5:D4:D3:BA:93:C0:D6:52:6E:88:D4:00:7F:18:0E:0E`

**⚠️ IMPORTANTE**: Este SHA-1 debe estar registrado en Firebase Console para que Google Sign-In funcione.

### Cómo obtener el SHA-1

#### Opción 1: Desde terminal (más rápido)

```bash
cd android
./gradlew signingReport
```

Busca en la salida algo como:
```
Variant: debug
Config: debug
Store: ~/.android/debug.keystore
Alias: AndroidDebugKey
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

#### Opción 2: Comando directo

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Busca la línea que dice `SHA1:` y copia el valor.

#### Opción 3: Si usas un keystore personalizado

```bash
keytool -list -v -keystore /path/to/your/keystore.jks -alias your-alias
```

### Registrar SHA-1 en Firebase Console

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto: `aifit-a7f6b`
3. Ve a **⚙️ Configuración del proyecto** (Project Settings)
4. Scroll hasta **"Tus aplicaciones"** (Your apps)
5. Selecciona tu app Android (la que tiene package name `com.example.aifit`)
6. Haz clic en **"Agregar huella digital"** (Add fingerprint)
7. Pega el SHA-1 que obtuviste
8. Haz clic en **"Guardar"** (Save)

**⚠️ IMPORTANTE**: Si no registras el SHA-1, Google Sign-In NO funcionará en Android.

## Verificar Configuración

### 1. Package Name

Verifica que el package name en estos archivos coincida:
- `android/app/build.gradle.kts`: `applicationId = "com.example.aifit"`
- `android/app/google-services.json`: `"package_name": "com.example.aifit"`
- `android/app/src/main/kotlin/com/example/aifit/MainActivity.kt`: `package com.example.aifit`

### 2. Google Services Plugin

Verifica en `android/app/build.gradle.kts`:
```kotlin
plugins {
    id("com.google.gms.google-services") // ✅ Debe estar presente
}
```

### 3. Internet Permission

Verifica en `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

## Probar Google Sign-In

Después de registrar el SHA-1:

1. **Limpia el build**:
   ```bash
   cd android
   ./gradlew clean
   cd ..
   flutter clean
   ```

2. **Reconstruye**:
   ```bash
   flutter pub get
   flutter run
   ```

3. **Prueba el login**: Debería abrir el selector de cuenta de Google

## Troubleshooting

### Error: "10: " (Error 10)
- **Causa**: SHA-1 no registrado o incorrecto
- **Solución**: Verifica que el SHA-1 esté correctamente registrado en Firebase Console

### Error: "12500: " (Error 12500)
- **Causa**: Google Sign-In no está habilitado en Firebase Console
- **Solución**: Ve a Firebase Console → Authentication → Sign-in method → Google → Habilitar

### Error: "7: " (Error 7)
- **Causa**: Package name no coincide
- **Solución**: Verifica que el package name en `build.gradle.kts` coincida con el de Firebase Console

## Notas

- El SHA-1 de **debug** es diferente al de **release**
- Si planeas publicar la app, también necesitarás registrar el SHA-1 de tu keystore de producción
- Puedes tener múltiples SHA-1 registrados (uno para debug, uno para release, etc.)
