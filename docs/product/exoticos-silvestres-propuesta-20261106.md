# Propuesta: Apartado de Exóticos y Silvestres

**Fecha:** 2026-11-06  
**Autor:** Mistralin (Vibe Code / Mistral Medium)  
**Sesión:** 7ecc57fd-0bcf-4ec6-aa93-5bca982af652  
**Área:** ClinicalBranch.exotic  
**Estado:** Propuesta inicial - En desarrollo

---

## Contexto

El sistema VetDosis ya tiene estructura para **Exóticos / Silvestres** (`ClinicalBranch.exotic`) en el código:
- `lib/modules/core/presentation/core_view_model.dart`: Enum definido
- `lib/modules/dashboard/presentation/home_pilot.dart`: Visualización en dashboard
- `lib/core/app.dart`: Integración en la app

Sin embargo, **no existe documentación ni implementación específica** para esta rama clínica, a diferencia de:
- **Pequeñas especies** (ClinicalBranch.small) - Implementado
- **Producción y grandes especies** (ClinicalBranch.production) - Porcinos en desarrollo (Claude)
- **Gestión clínica** (ClinicalBranch.management) - En desarrollo

Este documento propone la **estructura base para el apartado de Exóticos y Silvestres**.

---

## Alcance

El apartado de Exóticos y Silvestres debe cubrir:

### 1. **Especies objetivo**

| Categoría | Ejemplos | Características |
|-----------|----------|-----------------|
| **Aves exóticas** | Loros, canarios, periquitos, agapornis, cotorras | Metabolismo rápido, sensibilidad a toxinas |
| **Reptiles** | Tortugas, iguanas, serpientes, geckos | Ectotermos, manejo térmico crítico |
| **Peces ornamentales** | Goldfish, bettas, discus, koi | Calidad de agua, dosificación líquida |
| **Pequeños mamíferos** | Conejos, cobayas, hámsters, hurones | Variabilidad de tamaño y metabolismo |
| **Anfibios** | Ranitas, salamandras | Piel permeable, sensibilidad ambiental |
| **Invertebrados** | Tarántulas, escorpiones | Sistemas diferentes de dosificación |

### 2. **Módulos propuestos**

#### A. **Ficha Clínica Especializada**
- **Datos básicos:** Especie, raza/variedad, edad, peso, sexo
- **Parámetros ambientales:** Temperatura, humedad, tipo de hábitat
- **Historial:** Alimentación, suplementos, tratamientos previos
- **Específicos por tipo:**
  - Aves: Tipo de plumaje, capacidad de vuelo
  - Reptiles: Tipo de terrario, UVB, calor
  - Peces: pH, dureza, amoníaco, nitritos

#### B. **Calculadoras de Dosificación**

| Tipo | Parámetros | Fórmula base |
|------|-------------|--------------|
| **Peso corporal** | gramos/kg | mg/kg o mL/kg |
| **Volumen de agua** | litros | mg/L o mL/L |
| **Superficie corporal** | cm² | Para tópicos |
| **Metabolismo** | Factor especie | Ajuste por especie |

**Factores de conversión por especie:**
```
Aves: 1.0x (base)
Reptiles: 0.8x (metabolismo más lento)
Peces: 0.5x (metabolismo acuático)
Mamíferos pequeños: 1.2x (metabolismo rápido)
```

#### C. **Base de Datos de Fármacos**

Tabla de fármacos **seguros y contraindicados** por especie:

| Fármaco | Aves | Reptiles | Peces | Mamíferos | Notas |
|---------|------|----------|-------|-----------|-------|
| Enrofloxacino | ✅ | ✅ | ⚠️ | ✅ | Dosis ajustada |
| Ivermectina | ✅ | ❌ | ❌ | ✅ | Tóxico en reptiles |
| Metronidazol | ✅ | ✅ | ⚠️ | ✅ | Cuidado en peces |
| Meloxicam | ✅ | ✅ | ❌ | ✅ | No usar en peces |
| Itraconazol | ✅ | ✅ | ❌ | ✅ | - |

#### D. **Protocolos Clínicos**

**Protocolos comunes por especie:**

**Aves:**
- Parasitos internos/externos
- Infecciones respiratorias
- Problemas de plumaje
- Deficiencias nutricionales

**Reptiles:**
- Parasitos (nematodos, protozoarios)
- Infecciones bacterianas (abscesos)
- Problemas de muda
- Enfermedades metabólicas óseas

**Peces:**
- Ictioftiriasis (punto blanco)
- Columnariosis
- Infecciones bacterianas
- Problemas de calidad de agua

**Pequeños mamíferos:**
- Parasitos gastrointestinales
- Infecciones respiratorias
- Problemas dentales (cobayas, conejos)
- Tumores

#### E. **Guías de Manejo Ambiental**

**Parámetros críticos por especie:**

| Especie | Temp. Óptima (°C) | Humedad (%) | Iluminación | Espacio mínimo |
|---------|------------------|-------------|-------------|----------------|
| Loro | 20-26 | 50-70 | UVB 12h | 1m³ |
| Iguana | 26-32 (basking 38-40) | 70-80 | UVB 12-14h | 1.5m³ |
| Tortuga | 24-28 | 60-70 | UVB 12h | 2m² |
| Goldfish | 18-22 | - | - | 50L/pez |
| Conejo | 18-22 | 40-60 | Natural | 1m² |

---

## Estructura de Archivos Propuesta

```
docs/product/exoticos-silvestres/
├── README.md                    # Visión general
├── especies/
│   ├── aves-exoticas.md         # Guías específicas
│   ├── reptiles.md              # Guías específicas
│   ├── peces-ornamentales.md   # Guías específicas
│   ├── pequeños-mamiferos.md    # Guías específicas
│   └── anfibios-invertebrados.md
├── farmacos/
│   ├── lista-segura.md          # Fármacos por especie
│   ├── contraindicados.md       # Fármacos peligrosos
│   └── dosis-estandar.md        # Dosificaciones base
├── protocolos/
│   ├── aves/                    # Protocolos por especie
│   ├── reptiles/                # Protocolos por especie
│   └── peces/                   # Protocolos por especie
└── calculadoras/
    ├── dosificacion-peso.md     # Calculadoras
    └── dosificacion-volumen.md  # Calculadoras
```

---

## Integración con el Código Existente

### 1. **Rama Clínica**
Ya existe en `ClinicalBranch.exotic`:
```dart
enum ClinicalBranch {
  small('Pequeñas especies', Icons.pets_outlined),
  exotic('Exóticos / Silvestres', Icons.forest_outlined),  // <-- Ya definido
  production('Producción y grandes especies', Icons.agriculture_outlined),
  management('Gestión clínica', Icons.business_outlined);
}
```

### 2. **Dashboard**
Ya se visualiza en `home_pilot.dart`:
```dart
switch (branch) {
  ClinicalBranch.small => 'Pequeñas especies',
  ClinicalBranch.exotic => 'Exóticos',  // <-- Ya implementado
  _ => 'Producción y grandes especies',
}
```

### 3. **App Principal**
Integración en `app.dart`:
```dart
initialTool: model.branch == ClinicalBranch.exotic  // <-- Ya integrado
```

---

## Siguientes Pasos

### Fase 1: Documentación (1-2 días)
- [ ] Crear estructura de directorios `docs/product/exoticos-silvestres/`
- [ ] Documentar especies objetivo
- [ ] Crear tablas de fármacos seguros/contraindicados
- [ ] Definir protocolos clínicos básicos
- [ ] Documentar parámetros ambientales

### Fase 2: Implementación Básica (3-5 días)
- [ ] Crear modelos de datos para fichas clínicas de exóticos
- [ ] Implementar calculadoras de dosificación
- [ ] Crear interfaces para selección de especie
- [ ] Integrar con base de datos de fármacos

### Fase 3: Pruebas (2-3 días)
- [ ] Pruebas unitarias de calculadoras
- [ ] Pruebas de integración con otras ramas
- [ ] Validación clínica (requiere revisión de Ale)

### Fase 4: Integración (1-2 días)
- [ ] Merge con main
- [ ] Actualizar documentación general
- [ ] Registrar colaboradores

---

## Colaboración

**Mistralin (Vibe Code)** se encarga de:
- ✅ Crear estructura de documentación
- 🔄 Implementar módulo base
- 🔄 Coordinar con otros modelos

**Invitación a otros modelos:**
- **Claude:** ¿Quieres colaborar con la implementación de calculadoras?
- **GPT:** ¿Puedes ayudar con la base de datos de fármacos?
- **Buffy:** ¿Quieres revisar la integración con CI/CD?

---

## Evidencia y Seguimiento

- **Commit inicial:** [Por crear]
- **PR:** [Por crear]
- **Sesión:** 7ecc57fd-0bcf-4ec6-aa93-5bca982af652
- **Autor:** Mistralin (Vibe Code / Mistral Medium)
- **Autonomía:** Otorgada por Ale el 2026-11-06

---

## Notas

1. Este documento es una **propuesta inicial** basada en estándares veterinarios de exóticos
2. Requiere **validación clínica** antes de implementación
3. Se complementa con el trabajo de Claude en porcinos (producción y grandes especies)
4. Sigue el mismo patrón de documentación que el apartado de porcinos
5. La implementación debe ser **modular** para permitir expansión futura

---

*Documento creado por Mistralin (Vibe Code) con autonomía total otorgada por Ale*
