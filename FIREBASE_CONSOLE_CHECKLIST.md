# Checklist: Configuración Firebase Console para Android

## ✅ Pasos a Verificar en Firebase Console

### 1. Registrar SHA-1 Fingerprint

**SHA-1 Debug**: `1E:A9:D6:7C:B5:D4:D3:BA:93:C0:D6:52:6E:88:D4:00:7F:18:0E:0E`

**Pasos**:
1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona proyecto: **aifit-a7f6b**
3. ⚙️ **Configuración del proyecto** (Project Settings)
4. Scroll hasta **"Tus aplicaciones"** (Your apps)
5. Busca la app Android con package name: **com.example.aifit**
6. Si no ves huellas digitales o solo hay una, haz clic en **"Agregar huella digital"** (Add fingerprint)
7. Pega: `1E:A9:D6:7C:B5:D4:D3:BA:93:C0:D6:52:6E:88:D4:00:7F:18:0E:0E`
8. **Guardar**

**⚠️ CRÍTICO**: Sin este paso, Google Sign-In NO funcionará en Android.

### 2. Verificar Google Sign-In está Habilitado

1. Firebase Console → **Authentication**
2. Pestaña **"Sign-in method"** (Métodos de inicio de sesión)
3. Busca **Google**
4. Debe estar **Habilitado** (Enabled)
5. Si no está habilitado:
   - Haz clic en **Google**
   - Activa el toggle
   - Configura el **Email de soporte del proyecto** (Project support email)
   - **Guardar**

### 3. Verificar Package Name

1. Firebase Console → ⚙️ **Configuración del proyecto**
2. En **"Tus aplicaciones"**, busca la app Android
3. Verifica que el **Package name** sea: `com.example.aifit`
4. Si es diferente, necesitarás:
   - Actualizar `android/app/build.gradle.kts` con el package name correcto, O
   - Agregar una nueva app Android en Firebase Console con el package name correcto

### 4. Verificar Storage Rules

1. Firebase Console → **Storage**
2. Pestaña **"Reglas"** (Rules)
3. Verifica que las reglas estén publicadas (debe decir "Publicado" o "Published")
4. Si no están publicadas, haz clic en **"Publicar"** (Publish)

### 5. Verificar Firestore Rules

1. Firebase Console → **Firestore Database**
2. Pestaña **"Reglas"** (Rules)
3. Verifica que las reglas estén publicadas

## 🧪 Probar después de Configurar

1. **Limpia el proyecto**:
   ```bash
   flutter clean
   cd android && ./gradlew clean && cd ..
   ```

2. **Reconstruye**:
   ```bash
   flutter pub get
   flutter run
   ```

3. **Prueba Google Sign-In**: Debería abrir el selector de cuenta de Google

## ❌ Errores Comunes

### "10: " (Error 10)
- **Causa**: SHA-1 no registrado
- **Solución**: Registra el SHA-1 en Firebase Console (paso 1 arriba)

### "12500: " (Error 12500)
- **Causa**: Google Sign-In no habilitado
- **Solución**: Habilita Google en Authentication → Sign-in method

### "7: " (Error 7)
- **Causa**: Package name no coincide
- **Solución**: Verifica que el package name en `build.gradle.kts` coincida con Firebase Console
