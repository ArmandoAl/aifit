# Flujo de Agregar Prendas - Explicación de Logs

## Flujo Completo

### 1. Selección de Imágenes
```
📸 Opening image picker...
📸 Selected 1 images
📸 Navigating to AddWardrobeItemPage with 1 images
```
✅ **Significado**: El usuario seleccionó 1 imagen y se navegó a la pantalla de formulario.

### 2. Inicialización de la Pantalla
```
🔄 AddWardrobeItemPage initState
   - initialImages: 1
   - initialImages is null: false
   - Image path: /data/user/0/com.example.aifit/cache/scaled_37.jpg
   - Image exists: true
✅ Initialized with 1 images
```
✅ **Significado**: La pantalla se inicializó correctamente con la imagen seleccionada.

### 3. Renderizado de la UI
```
🏗️ AddWardrobeItemPage build - images: 1
🏗️ Is single item: true
```
✅ **Significado**: La UI se está renderizando con 1 imagen (modo "single item").

### 4. Al Presionar "Save"
```
💾 Save button pressed
   - Images: 1
   - Form data: 1
✅ Form validation passed
```
✅ **Significado**: El usuario presionó "Save" y el formulario es válido.

### 5. Subida a Storage
```
📦 Adding wardrobe item:
   - User ID: bjHpPUDv1FMlk2ourMYniXjMpW72
   - Type: bottom
   - SubType: pants
   - Brand: none
📤 Uploading image to Storage...
✅ Image uploaded: https://firebasestorage.googleapis.com/...
```
✅ **Significado**: La imagen se subió exitosamente a Firebase Storage.

### 6. Guardado en Firestore
```
💾 Saving to Firestore...
✅ Wardrobe item saved to Firestore: abc123xyz
```
✅ **Significado**: El documento se guardó en Firestore con ID `abc123xyz`.

### 7. Éxito Final
```
Items added successfully! 🎉
```
✅ **Significado**: Todo el proceso se completó exitosamente.

---

## Errores Comunes

### Error: `NOT_FOUND - database does not exist`
```
W/Firestore: Status{code=NOT_FOUND, description=The database (default) does not exist}
```

**Causa**: Firestore no está habilitado en Firebase Console.

**Solución**:
1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto: **aifit-a7f6b**
3. Ve a **Firestore Database** → **Create database**
4. Selecciona **"Start in production mode"**
5. Elige una ubicación y haz clic en **"Enable"**

**Ver guía completa**: `FIRESTORE_SETUP.md`

---

### Error: `User not logged in`
```
Exception: User not logged in
```

**Causa**: El usuario no está autenticado.

**Solución**: Asegúrate de estar logueado antes de agregar prendas.

---

### Error: Form validation failed
```
❌ Form validation failed
```

**Causa**: Faltan campos requeridos (Type o Sub-type).

**Solución**: Completa todos los campos marcados con `*` antes de presionar "Save".

---

## Dónde Ver los Datos Guardados

### Firebase Storage
- **Ruta**: `users/{uid}/wardrobe/{timestamp}.jpg`
- **Cómo ver**: Firebase Console → Storage → Navega a `users/{tu_uid}/wardrobe/`

### Firestore
- **Colección**: `wardrobe_items`
- **Cómo ver**: Firebase Console → Firestore Database → Colección `wardrobe_items`
- **Campos**:
  - `userId`: ID del usuario
  - `imageUrl`: URL de la imagen en Storage
  - `type`: Tipo principal (top, bottom, shoes, outerwear)
  - `subType`: Subtipo (t-shirt, jeans, etc.)
  - `brand`: Marca (opcional)
  - `colors`: Array de colores detectados por AI
  - `styleTags`: Array de estilos detectados por AI
  - `createdAt`: Timestamp de creación

---

## Checklist Antes de Agregar Prendas

- [ ] Firestore habilitado en Firebase Console
- [ ] Usuario autenticado (logueado)
- [ ] Imagen seleccionada
- [ ] Tipo seleccionado (Type *)
- [ ] Subtipo seleccionado (Sub-type *)
- [ ] Botón "Save" visible en el AppBar (esquina superior derecha)

---

## Notas

- **El botón "Save" está en el AppBar** (esquina superior derecha), no en el body de la pantalla.
- **No se guarda automáticamente al regresar**: Debes presionar "Save" explícitamente.
- **Los datos se guardan en dos lugares**:
  1. **Storage**: La imagen física
  2. **Firestore**: Los metadatos (tipo, marca, etc.) + URL de la imagen
