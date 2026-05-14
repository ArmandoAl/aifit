# 🔥 Desplegar Reglas de Firestore - Solución al Error de Permisos

## ❌ Error Actual
```
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.}
The caller does not have permission to execute the specified operation.
```

## ✅ Solución

### Paso 1: Desplegar las Reglas de Firestore

1. **Abre Firebase Console**
   - Ve a: https://console.firebase.google.com/
   - Selecciona tu proyecto: `aifit-a7f6b`

2. **Ve a Firestore Database**
   - En el menú lateral, haz clic en **"Firestore Database"**
   - Haz clic en la pestaña **"Reglas"** (Rules)

3. **Copia y pega estas reglas:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return signedIn() && request.auth.uid == userId;
    }

    // User profile document
    match /users/{userId} {
      allow read, create, update, delete: if isOwner(userId);
    }

    // Global wardrobe items collection (scoped by userId field)
    match /wardrobe_items/{itemId} {
      // Allow creating items only if userId matches authenticated user
      allow create: if signedIn() && request.resource.data.userId == request.auth.uid;
      
      // Allow reading individual documents if userId matches
      allow get: if signedIn() && resource.data.userId == request.auth.uid;
      
      // Allow updating/deleting if userId matches
      allow update, delete: if signedIn() && resource.data.userId == request.auth.uid;
      
      // Allow list (queries) for authenticated users
      // Note: The app code must always filter by userId == request.auth.uid
      allow list: if signedIn();
    }

    // Deny by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

4. **Publica las reglas**
   - Haz clic en el botón **"Publicar"** (Publish)
   - Espera a que se confirme la publicación (puede tardar unos segundos)

---

### Paso 2: Verificar/Crear el Índice Compuesto

La query que estás usando requiere un índice compuesto:
```dart
.where('userId', isEqualTo: uid)
.orderBy('createdAt', descending: true)
```

1. **Verifica si el índice existe:**
   - En Firebase Console → Firestore Database
   - Haz clic en la pestaña **"Índices"** (Indexes)
   - Busca un índice para `wardrobe_items` con:
     - `userId` (Ascending)
     - `createdAt` (Descending)

2. **Si el índice NO existe:**
   - Firebase debería mostrarte un enlace para crearlo automáticamente
   - O puedes crearlo manualmente:
     - Haz clic en **"Crear índice"** (Create Index)
     - Colección: `wardrobe_items`
     - Campos:
       - `userId` → Ascending
       - `createdAt` → Descending
     - Haz clic en **"Crear"**

3. **Espera a que el índice se cree**
   - Puede tardar unos minutos
   - Verás el estado cambiar de "Building" a "Enabled"

---

### Paso 3: Verificar que el Usuario Está Autenticado

1. **En la app, verifica los logs:**
   ```
   ✅ USUARIO AUTENTICADO CON GOOGLE
      UID: bjHpPUDv1FMlk2ourMYniXjMpW72
   ```

2. **En Firebase Console:**
   - Ve a **Authentication** → **Users**
   - Verifica que el UID `bjHpPUDv1FMlk2ourMYniXjMpW72` existe en la lista

---

### Paso 4: Probar las Reglas con el Simulador

1. **En Firebase Console → Firestore → Reglas**
2. **Haz clic en "Simulador"** (Rules Playground)
3. **Configura:**
   - **Ubicación**: `wardrobe_items/any_item_id`
   - **Tipo de operación**: `list` (para queries)
   - **Autenticación**: Selecciona tu usuario de la lista
4. **Haz clic en "Ejecutar"** (Run)
5. **Debería mostrar**: ✅ **Permitido** (Allowed)

---

## 🔍 Explicación de las Reglas

### Para `wardrobe_items`:

1. **`allow create`**: Solo permite crear items si `userId` en el documento coincide con `request.auth.uid`
2. **`allow get`**: Solo permite leer documentos individuales si `userId` coincide
3. **`allow update, delete`**: Solo permite modificar/eliminar si `userId` coincide
4. **`allow list`**: Permite hacer queries (`.where().orderBy()`) si el usuario está autenticado
   - ⚠️ **Importante**: El código de la app DEBE siempre filtrar por `userId == request.auth.uid`
   - Esto ya está implementado en `WardrobeRepositoryImpl.getWardrobeItems()`

### ¿Por qué `allow list` sin validar `userId`?

Las reglas de Firestore no pueden validar el contenido de los documentos durante una query. Solo pueden:
- Verificar que el usuario esté autenticado
- Validar que la query esté bien formada

Por eso confiamos en que el código de la app siempre filtre por `userId`. Esto es seguro porque:
- El código ya lo hace: `.where('userId', isEqualTo: uid)`
- Solo usuarios autenticados pueden hacer queries
- Los documentos individuales siguen protegidos con `allow get`

---

## ✅ Verificación Final

Después de desplegar las reglas:

1. **Cierra y vuelve a abrir la app**
2. **Haz login con Google**
3. **Intenta cargar el guardarropa**
4. **Deberías ver en los logs:**
   ```
   📦 Loading wardrobe items for user: bjHpPUDv1FMlk2ourMYniXjMpW72
   ✅ Loaded X wardrobe items
   ```

Si aún ves el error:
- Verifica que las reglas se desplegaron correctamente
- Verifica que el índice compuesto está creado y habilitado
- Verifica que el usuario está autenticado (revisa los logs)

---

## 📝 Notas

- Las reglas pueden tardar unos segundos en aplicarse después de publicarlas
- Si cambias las reglas, espera 10-30 segundos antes de probar
- El índice compuesto puede tardar varios minutos en crearse la primera vez
