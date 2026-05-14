# Troubleshooting: Google Sign-In en Android

## Error: "GetCredentialResponse error" / "Google Sign-In cancelled by user"

Este error generalmente ocurre por una de estas razones:

### 1. ✅ SHA-1 Fingerprint NO Registrado

**Síntoma**: El login se cancela inmediatamente sin mostrar selector de cuentas.

**Solución**:
1. Obtén tu SHA-1:
   ```bash
   cd android
   ./gradlew signingReport
   ```
2. Busca la línea `SHA1:` (debe ser: `1E:A9:D6:7C:B5:D4:D3:BA:93:C0:D6:52:6E:88:D4:00:7F:18:0E:0E`)
3. Ve a Firebase Console → ⚙️ Configuración del proyecto
4. Selecciona tu app Android → "Agregar huella digital"
5. Pega el SHA-1 y guarda

### 2. ✅ Emulador sin Google Play Services

**Síntoma**: El error ocurre inmediatamente, no hay selector de cuentas.

**Solución**:
- **Asegúrate de usar un emulador con Google Play Services**:
  1. Android Studio → AVD Manager
  2. Crea un nuevo emulador O selecciona uno existente
  3. **IMPORTANTE**: Elige una imagen del sistema que tenga el ícono de "Play Store" (Google Play)
  4. Ejemplos: "Pixel 5 API 33" con Google Play, NO "Pixel 5 API 33" sin Google Play

### 3. ✅ No hay Cuentas de Google en el Emulador

**Síntoma**: Se muestra el selector pero está vacío o se cancela.

**Solución**:
1. Abre **Settings** en el emulador
2. Ve a **Accounts** → **Add account**
3. Agrega una cuenta de Google
4. Vuelve a intentar el login

### 4. ✅ Server Client ID (Web Client ID) Faltante

**Síntoma**: El error ocurre después de seleccionar cuenta.

**Solución**: Ya está implementado en el código. El `serverClientId` se pasa automáticamente:
- Web Client ID: `268248668862-f1fp960traqm1i0t6ir8sms4qt23339d.apps.googleusercontent.com`

Si necesitas verificar/obtener el Web Client ID:
1. Firebase Console → ⚙️ Configuración del proyecto
2. Scroll hasta "Tus aplicaciones"
3. Selecciona tu app Android
4. Busca "OAuth 2.0 Client IDs"
5. Busca el que dice "Web application" (tipo 3)
6. Copia el "Client ID"

### 5. ✅ Google Sign-In NO Habilitado en Firebase

**Síntoma**: Error al intentar autenticar.

**Solución**:
1. Firebase Console → **Authentication**
2. Pestaña **"Sign-in method"**
3. Busca **Google**
4. Debe estar **Habilitado**
5. Si no, haz clic y activa el toggle
6. Configura el "Email de soporte del proyecto"
7. **Guardar**

## Verificación Rápida

Ejecuta estos comandos para verificar:

```bash
# 1. Verificar SHA-1
cd android && ./gradlew signingReport | grep SHA1

# 2. Limpiar y reconstruir
cd ..
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
```

## Logs Útiles

El código ahora imprime estos logs:

```
🔐 Google Sign-In - Starting...
   Platform: android
✅ Google Sign-In initialized
   Attempting authentication...
✅ Google user authenticated: user@example.com
✅ Google idToken obtained
✅ Firebase user signed in: uid=... email=...
```

Si ves:
- `⚠️ Google Sign-In cancelled by user` → Verifica SHA-1 y Google Play Services
- `❌ Google authentication missing idToken` → Verifica que Google Sign-In esté habilitado en Firebase

## Checklist Completo

- [ ] SHA-1 registrado en Firebase Console
- [ ] Emulador tiene Google Play Services (ícono de Play Store)
- [ ] Al menos una cuenta de Google agregada en el emulador
- [ ] Google Sign-In habilitado en Firebase Console
- [ ] Package name coincide: `com.example.aifit`
- [ ] `google-services.json` presente en `android/app/`
- [ ] Plugin `com.google.gms.google-services` en `build.gradle.kts`

## Probar en Dispositivo Físico

Si el emulador sigue dando problemas:

1. Conecta un dispositivo Android físico
2. Habilita **Depuración USB**
3. Ejecuta: `flutter run`
4. El dispositivo físico generalmente tiene Google Play Services configurado

## Contacto

Si después de verificar todo lo anterior el problema persiste, comparte:
- Los logs completos de Flutter
- El tipo de emulador que estás usando
- Si el SHA-1 está registrado en Firebase Console
