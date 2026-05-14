# 🔧 Solución: Error de Índice Compuesto en Firestore

## ❌ Error Actual
```
FAILED_PRECONDITION: The query requires an index
Query: wardrobe_items where userId==... order by -createdAt, -__name__
```

## 🔍 Problema

La query que estás usando requiere un índice compuesto con **3 campos**:
1. `userId` (Ascendente)
2. `createdAt` (Descendente)  
3. `__name__` (Descendente) ← **Este es el que falta**

Firestore automáticamente agrega `__name__` (el ID del documento) al final de las queries con `orderBy` para garantizar un orden determinístico.

## ✅ Solución Rápida (Recomendada)

**Usa el enlace que Firebase te proporciona en el error:**

1. **Copia este enlace del error:**
   ```
   https://console.firebase.google.com/v1/r/project/aifit-a7f6b/firestore/databases/aifitdbex/indexes?create_composite=ClJwcm9qZWN0cy9haWZpdC1hN2Y2Yi9kYXRhYmFzZXMvYWlmaXRkYmV4L2NvbGxlY3Rpb25Hcm91cHMvd2FyZHJvYmVfaXRlbXMvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaDQoJY3JlYXRlZEF0EAIaDAoIX19uYW1lX18QAg
   ```

2. **Ábrelo en tu navegador**
   - Te llevará directamente a la página de creación del índice
   - Ya tendrá todos los campos pre-configurados correctamente

3. **Haz clic en "Crear"**
   - El índice se creará automáticamente con la configuración correcta

4. **Espera a que se cree**
   - Puede tardar unos minutos
   - Verás el estado cambiar de "Building" a "Enabled"

---

## 🔧 Solución Manual (Si prefieres hacerlo tú mismo)

Si prefieres crear el índice manualmente:

1. **Ve a Firebase Console**
   - Firestore Database → Índices

2. **Haz clic en "Crear índice"**

3. **Configura:**
   - **ID de la colección**: `wardrobe_items`
   - **Permisos de las consultas**: `Colección`

4. **Agrega los campos:**
   - **Campo 1**: `userId` → **Ascendente**
   - **Campo 2**: `createdAt` → **Descendente**
   - **Campo 3**: `__name__` → **Descendente** ← **Este es el importante**

5. **Haz clic en "Crear"**

---

## 📝 ¿Por qué `__name__`?

`__name__` es el ID del documento en Firestore. Firestore lo agrega automáticamente al final de las queries con `orderBy` para:
- Garantizar un orden determinístico (si dos documentos tienen el mismo `createdAt`, se ordenan por ID)
- Mejorar el rendimiento de las queries

Por eso el índice debe incluir también `__name__`.

---

## ✅ Verificación

Después de crear el índice:

1. **Espera 2-5 minutos** para que el índice se cree completamente
2. **Reinicia la app**
3. **Intenta cargar el guardarropa**
4. **Deberías ver en los logs:**
   ```
   📦 Loading wardrobe items for user: bjHpPUDv1FMlk2ourMYniXjMpW72
   ✅ Loaded X wardrobe items
   ```

---

## 🎯 Resumen

**Usa el enlace del error** - Es la forma más rápida y garantiza que el índice tenga todos los campos correctos:
- `userId` (Ascendente)
- `createdAt` (Descendente)
- `__name__` (Descendente)
