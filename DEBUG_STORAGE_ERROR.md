# Guía para Debuggear Error -1017 de Firebase Storage

## ¿Qué es el error -1017?

El error `[firebase_storage/unknown] Unexpected -1017 code from backend` generalmente indica un problema de **autenticación o permisos** en Firebase Storage.

## Causas Comunes

1. **Usuario no autenticado**: El token de Firebase Auth expiró o el usuario se deslogueó
2. **Reglas de Storage muy restrictivas**: Las reglas requieren autenticación pero el token no se está enviando correctamente
3. **Problema de red/conectividad**: El token de autenticación no se puede validar
4. **Token expirado**: El token de Firebase Auth expiró y necesita refrescarse

## Cómo Debuggear en Firebase Console

### 1. Ver Logs de Storage

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto: `aifit-a7f6b`
3. En el menú lateral, ve a **Storage**
4. Haz clic en la pestaña **"Reglas"** (Rules)
5. Haz clic en **"Registros"** (Logs) o **"Monitoreo"** (Monitoring)

**Nota**: Los logs de Storage pueden tener un delay de varios minutos.

### 2. Verificar Reglas de Storage

1. En Firebase Console → **Storage** → **Reglas**
2. Verifica que las reglas actuales sean:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function signedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return signedIn() && request.auth.uid == userId;
    }

    match /users/{userId}/{allPaths=**} {
      allow read, write: if isOwner(userId);
    }

    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

3. **Para desarrollo/debug temporal**, puedes hacer las reglas más permisivas:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // TEMPORAL: Solo para debug - REMOVER EN PRODUCCIÓN
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deny by default
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

4. Haz clic en **"Publicar"** (Publish) para aplicar los cambios

### 3. Verificar Autenticación del Usuario

En la consola de Flutter, busca estos logs:

```
✅ User authenticated: <uid>
📤 Uploading photo to: users/<uid>/photos/...
```

Si ves:
```
❌ No authenticated user - cannot upload to Storage
```

Significa que el usuario no está autenticado. Solución: hacer logout y login nuevamente.

### 4. Ver Logs de Firebase Auth

1. Firebase Console → **Authentication** → **Usuarios**
2. Verifica que tu usuario esté listado
3. Revisa la columna **"Última actividad"** (Last sign-in)

### 5. Probar las Reglas con el Simulador

1. Firebase Console → **Storage** → **Reglas**
2. Haz clic en **"Simulador"** (Rules Playground)
3. Configura:
   - **Ubicación**: `users/{userId}/photos/photo.jpg`
   - **Tipo de operación**: `write`
   - **Autenticación**: Selecciona tu usuario de la lista
4. Haz clic en **"Ejecutar"** (Run)
5. Debería mostrar: ✅ **Permitido** (Allowed)

Si muestra ❌ **Denegado** (Denied), las reglas están bloqueando el acceso.

## Soluciones

### Solución 1: Refrescar Autenticación

```dart
// En tu código, antes de subir:
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // Redirigir a login
} else {
  // Forzar refresh del token
  await user.getIdToken(true); // true = force refresh
  // Ahora intenta subir
}
```

### Solución 2: Verificar que el userId coincida

El error puede ocurrir si el `userId` que pasas no coincide con `request.auth.uid` en las reglas.

**Verifica en los logs:**
```
✅ User authenticated: bjHpPUDv1FMlk2ourMYniXjMpW72
📤 Uploading photo to: users/bjHpPUDv1FMlk2ourMYniXjMpW72/photos/...
```

Ambos deben ser el mismo UID.

### Solución 3: Temporalmente Abrir Reglas (Solo para Debug)

⚠️ **ADVERTENCIA**: Esto es solo para desarrollo. NUNCA en producción.

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // TEMPORAL: Permitir todo para usuarios autenticados
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### Solución 4: Verificar Network/Conectividad

El error -1017 también puede ocurrir si:
- Hay problemas de red
- El dispositivo está en modo avión
- Hay un firewall bloqueando Firebase

**Prueba:**
1. Verifica tu conexión a internet
2. Intenta desde otro dispositivo/red
3. Verifica que Firebase esté accesible: `ping firebasestorage.googleapis.com`

## Logs Útiles en Flutter

El código ahora imprime estos logs cuando hay un error:

```
❌ Error uploading photo: [firebase_storage/unknown] Unexpected -1017 code from backend
❌ Error type: FirebaseException
❌ Current user: bjHpPUDv1FMlk2ourMYniXjMpW72 (o null si no está autenticado)
❌ Storage error -1017: This usually means authentication/permission issue
   - Check if user is logged in: true/false
   - Check Storage rules in Firebase Console
```

## Checklist de Debug

- [ ] Usuario está autenticado (ver logs: `✅ User authenticated`)
- [ ] El `userId` en la ruta coincide con `request.auth.uid`
- [ ] Las reglas de Storage están publicadas correctamente
- [ ] El simulador de reglas permite la operación
- [ ] No hay problemas de red/conectividad
- [ ] El token de Firebase Auth no expiró (hacer logout/login)

## Contacto con Firebase Support

Si el problema persiste después de verificar todo lo anterior:

1. Ve a [Firebase Support](https://firebase.google.com/support)
2. Proporciona:
   - El error completo con stack trace
   - El UID del usuario
   - La ruta que intentas subir
   - Una captura de las reglas de Storage
   - Los logs de Firebase Console
