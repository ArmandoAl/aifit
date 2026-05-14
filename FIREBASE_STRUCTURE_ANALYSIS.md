# 📊 Análisis de Estructura de Firebase - AIFit

## 🎯 Objetivo
Este documento analiza la estructura de datos en Firebase (Firestore y Storage) para asegurar que todos los datos estén correctamente organizados por usuario y asociados con el UID real de Firebase Auth.

---

## 🔍 Problema Identificado

### Carpetas `mock_user_*` en Firebase Storage
Se detectaron carpetas con nombres como `mock_user_<timestamp>` en Firebase Storage, lo que indica que en algún momento se usaron IDs mock en lugar de UIDs reales de Firebase Auth.

**Causa raíz:**
- Durante desarrollo inicial, se usó autenticación mock (offline)
- Los IDs generados eran del formato `mock_user_<timestamp>`
- Estos IDs se usaron para crear rutas en Storage y documentos en Firestore
- Al migrar a autenticación real, algunos flujos podrían seguir usando IDs mock

---

## ✅ Estructura Correcta de Datos

### Firebase Authentication
- **Ubicación**: Firebase Console → Authentication → Users
- **Formato**: Cada usuario tiene un `uid` único generado por Firebase
- **Ejemplo**: `bjHpPUDv1FMlk2ourMYniXjMpW72`

### Firestore Database

#### Colección: `users/{uid}`
**Estructura:**
```json
{
  "displayName": "John Doe",
  "email": "john@example.com",
  "photoUrl": "https://...",
  "createdAt": "2026-01-23T...",
  "lastLogin": "2026-01-23T...",
  "updatedAt": "2026-01-23T...",
  "preferences": {
    "styleTags": ["casual", "formal"],
    "temperatureSensitivity": "medium"
  },
  "bodyPhotos": [
    "https://firebasestorage.googleapis.com/...",
    "https://firebasestorage.googleapis.com/..."
  ],
  "facePhotos": [
    "https://firebasestorage.googleapis.com/..."
  ],
  "onboardingCompleted": true
}
```

**Reglas de Seguridad:**
- Solo el usuario autenticado puede leer/escribir su propio documento
- Regla: `request.auth.uid == userId`

#### Colección: `wardrobe_items/{itemId}`
**Estructura:**
```json
{
  "userId": "bjHpPUDv1FMlk2ourMYniXjMpW72",  // UID del usuario
  "imageUrl": "https://firebasestorage.googleapis.com/...",
  "name": "Blue Jeans",
  "type": "bottom",
  "subType": "jeans",
  "colors": ["blue", "navy"],
  "styleTags": ["casual"],
  "season": ["spring", "summer", "fall"],
  "brand": "Levi's",
  "createdAt": "2026-01-23T..."
}
```

**Reglas de Seguridad:**
- Solo el usuario puede crear items con su propio `userId`
- Solo el usuario puede leer/escribir items donde `resource.data.userId == request.auth.uid`

### Firebase Storage

#### Estructura de Rutas
```
users/
  └── {uid}/                    # UID real de Firebase Auth
      ├── photos/
      │   ├── body_1234567890.jpg
      │   ├── body_1234567891.jpg
      │   ├── face_1234567892.jpg
      │   └── face_1234567893.jpg
      └── wardrobe/
          ├── item_1234567894.jpg
          └── item_1234567895.jpg
```

**Reglas de Seguridad:**
- Solo el usuario autenticado puede leer/escribir en `users/{uid}/...`
- Regla: `request.auth.uid == userId`

---

## 🔒 Validaciones Implementadas

### 1. AuthRepository
- ✅ Usa `FirebaseAuth.instance` para obtener UID real
- ✅ Sincroniza usuario a Firestore en `users/{uid}`
- ✅ Logs mejorados para imprimir UID después del login

### 2. StorageService
- ✅ Valida que el usuario esté autenticado
- ✅ Valida que `userId` coincida con `currentUser.uid`
- ✅ **NUEVO**: Rechaza IDs que empiecen con `mock_` o contengan `mock_user`
- ✅ Logs mejorados para mostrar rutas de Storage

### 3. AuthHelper (Nuevo)
- ✅ Helper centralizado para obtener UID
- ✅ Validación automática de IDs mock
- ✅ Métodos para validar coincidencia de userId

### 4. Repositorios
- ✅ `WardrobeRepositoryImpl`: Usa `_auth.currentUser?.uid`
- ✅ `ProfileRepository`: Recibe `userId` del AuthBloc
- ✅ `StylistRepositoryImpl`: Usa `_auth.currentUser?.uid`

---

## 📝 Flujo de Autenticación Correcto

### 1. Login con Google
```
Usuario → LoginPage → AuthBloc → AuthRepository.signInWithGoogle()
  ↓
Google Sign-In → Firebase Auth → Obtiene UID real
  ↓
AuthRepository._syncFirebaseUserToFirestore(uid)
  ↓
Crea/actualiza: users/{uid} en Firestore
  ↓
AuthBloc emite: AuthAuthenticated(user)
  ↓
Router navega a la app
```

### 2. Uso del UID en la App
```
AuthBloc.state → AuthAuthenticated(user)
  ↓
user.id → UID real de Firebase Auth
  ↓
Se pasa a todos los servicios:
  - ProfileRepository.uploadBodyPhotos(userId: user.id)
  - StorageService.uploadUserPhoto(userId: user.id)
  - WardrobeRepositoryImpl (usa _auth.currentUser.uid directamente)
```

---

## ⚠️ Puntos de Atención

### 1. IDs Mock Detectados
Si ves carpetas `mock_user_*` en Storage:
- **No son usuarios reales** de Firebase Auth
- Fueron creados durante desarrollo con autenticación mock
- **Solución**: Eliminar manualmente desde Firebase Console si es necesario

### 2. Verificación de Usuario Real
Para verificar que estás usando un usuario real:
1. Firebase Console → Authentication → Users
2. Busca el UID que aparece en los logs
3. Debe existir en la lista de usuarios autenticados

### 3. Logs de Debug
Después del login, busca estos logs:
```
═══════════════════════════════════════════════════
✅ USUARIO AUTENTICADO CON GOOGLE
   UID: bjHpPUDv1FMlk2ourMYniXjMpW72
   Email: user@example.com
   Nombre: John Doe
═══════════════════════════════════════════════════
📝 IMPORTANTE: Todos los datos se asociarán con este UID
   - Firestore: users/bjHpPUDv1FMlk2ourMYniXjMpW72
   - Storage: users/bjHpPUDv1FMlk2ourMYniXjMpW72/...
═══════════════════════════════════════════════════
```

---

## 🧪 Testing

### Verificar que el Login Funciona
1. Ejecuta la app
2. Haz login con Google
3. Revisa los logs en la consola:
   - Debe aparecer el UID real
   - No debe aparecer ningún `mock_user_*`

### Verificar Storage
1. Sube una foto desde ProfilePage o PhotoSetupPage
2. Revisa Firebase Console → Storage
3. La ruta debe ser: `users/{uid_real}/photos/...`
4. No debe crear carpetas `mock_user_*`

### Verificar Firestore
1. Firebase Console → Firestore Database
2. Debe existir un documento en `users/{uid_real}`
3. El documento debe tener los campos correctos
4. No debe haber documentos con IDs mock

---

## 📋 Checklist de Implementación

- [x] AuthRepository usa Firebase Auth real
- [x] StorageService valida UID real
- [x] StorageService rechaza IDs mock
- [x] Logs mejorados para mostrar UID
- [x] AuthHelper creado para validación centralizada
- [x] Documentación de estructura creada
- [ ] Testing con usuario real completado
- [ ] Limpieza de datos mock (si es necesario)

---

## 🔄 Próximos Pasos

1. **Probar login real con Google**
   - Verificar que el UID se imprime correctamente
   - Verificar que los datos se guardan en las rutas correctas

2. **Limpiar datos mock (opcional)**
   - Si hay carpetas `mock_user_*` en Storage, eliminarlas manualmente
   - Si hay documentos mock en Firestore, eliminarlos

3. **Monitorear logs**
   - Asegurar que no aparezcan más IDs mock
   - Verificar que todas las operaciones usen UID real

---

## 📚 Referencias

- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Storage Security Rules](https://firebase.google.com/docs/storage/security)
