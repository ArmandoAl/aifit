# Firestore Setup - Solución al Error "database does not exist"

## Error

```
Status{code=NOT_FOUND, description=The database (default) does not exist for project aifit-a7f6b
Please visit https://console.cloud.google.com/datastore/setup?project=aifit-a7f6b
```

## Causa

Firestore **no está habilitado** en tu proyecto de Firebase. Esto es necesario para que la app pueda leer/escribir datos.

## Solución: Habilitar Firestore

### Paso 1: Ir a Firebase Console

1. Abre [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto: **aifit-a7f6b**

### Paso 2: Habilitar Firestore

1. En el menú lateral izquierdo, busca **"Firestore Database"** (o "Cloud Firestore")
2. Si no lo ves, haz clic en **"Build"** → **"Firestore Database"**
3. Haz clic en **"Create database"** (o "Crear base de datos")

### Paso 3: Configurar Firestore

1. **Modo de producción**:
   - Selecciona **"Start in production mode"** (o "Iniciar en modo de producción")
   - Esto aplicará las reglas de seguridad que ya tienes en `firestore.rules`

2. **Ubicación**:
   - Elige una región cercana (por ejemplo: `us-central`, `southamerica-east1` para Latinoamérica)
   - **Nota**: Una vez elegida, no se puede cambiar

3. Haz clic en **"Enable"** (o "Habilitar")

### Paso 4: Verificar que Funciona

Después de habilitar Firestore:

1. Deberías ver la pantalla de Firestore Database con el mensaje "No collections yet"
2. Vuelve a ejecutar tu app: `flutter run`
3. Intenta agregar una prenda nuevamente
4. El error debería desaparecer

## Verificar Reglas de Seguridad

Una vez habilitado, verifica que las reglas estén desplegadas:

1. En Firestore Database, ve a la pestaña **"Rules"**
2. Deberías ver algo como:

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
    match /users/{userId} {
      allow read, create, update, delete: if isOwner(userId);
    }
    match /wardrobe_items/{itemId} {
      allow create: if signedIn() && request.resource.data.userId == request.auth.uid;
      allow read, update, delete: if signedIn() && resource.data.userId == request.auth.uid;
    }
    match /{document=**} {
      allow read, write: if false; // Deny by default
    }
  }
}
```

3. Si no coinciden, copia el contenido de `firestore.rules` y haz clic en **"Publish"**

## Desplegar Reglas desde la Terminal (Opcional)

Si prefieres desplegar las reglas desde la terminal:

```bash
# Instalar Firebase CLI (si no lo tienes)
npm install -g firebase-tools

# Login
firebase login

# Inicializar (si es la primera vez)
firebase init firestore

# Desplegar reglas
firebase deploy --only firestore:rules
```

## Notas Importantes

- **Firestore es diferente de Realtime Database**: Asegúrate de habilitar **Firestore**, no "Realtime Database"
- **Costo**: Firestore tiene un tier gratuito generoso para desarrollo. Revisa [pricing](https://firebase.google.com/pricing)
- **Índices**: Si ves errores sobre índices faltantes, ve a Firestore → Indexes y crea los índices sugeridos (o despliega `firestore.indexes.json`)

## Checklist

- [ ] Firestore Database habilitado en Firebase Console
- [ ] Modo de producción seleccionado
- [ ] Reglas de seguridad desplegadas
- [ ] App ejecutada nuevamente (`flutter run`)
- [ ] Error "database does not exist" desapareció

## Si el Error Persiste

1. **Verifica el proyecto**: Asegúrate de que `firebase_options.dart` tenga el `projectId` correcto: `aifit-a7f6b`
2. **Limpia y reconstruye**:
   ```bash
   flutter clean
   flutter pub get
   cd android && ./gradlew clean && cd ..
   flutter run
   ```
3. **Verifica la conexión**: Asegúrate de tener internet y que Firebase Console esté accesible
