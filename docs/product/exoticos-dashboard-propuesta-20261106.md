# Propuesta: Dashboard y Pantalla para Exóticos / Silvestres

**Fecha:** 2026-11-06  
**Autor:** Mistralin (Vibe Code / Mistral Medium)  
**Sesión:** 7ecc57fd-0bcf-4ec6-aa93-5bca982af652  
**Área:** ClinicalBranch.exotic  
**Estado:** Propuesta de implementación  
**Dependencias:** Supabase (Solar y Mimo de Buffy tienen acceso)

---

## 📋 Resumen Ejecutivo

El sistema VetDosis **ya tiene la infraestructura base** para Exóticos/Silvestres:
- ✅ `ClinicalBranch.exotic` definido en `core_view_model.dart`
- ✅ Selector de branch en dashboard (`home_pilot.dart`)
- ✅ Integración en `app.dart` (initialTool: 'metabolic')
- ✅ Icono y etiqueta: "Exóticos / Silvestres" con `Icons.forest_outlined`

**Falta:**
- ❌ **Dashboard específico** para Exóticos
- ❌ **Pantalla principal** que muestre módulos relevantes
- ❌ **Estructura de datos en Supabase** para exóticos
- ❌ **Configuración de ClinicPreset** para exóticos

---

## 🎯 Objetivo

Crear un **dashboard y pantalla principal** para el área de Exóticos que:
1. Muestre módulos relevantes para veterinarios de exóticos
2. Integre con Supabase (Solar y Mimo ya tienen acceso)
3. Siga el mismo patrón que pequeñas especies y producción
4. Sea configurable por clínica

---

## 🔍 Análisis del Código Existente

### 1. ClinicalBranch (Ya implementado)

```dart
// lib/modules/core/presentation/core_view_model.dart
enum ClinicalBranch {
  small('Pequeñas especies', Icons.pets_outlined),
  exotic('Exóticos / Silvestres', Icons.forest_outlined),  // ✅ Existe
  production('Producción y grandes especies', Icons.agriculture_outlined),
  management('Gestión clínica', Icons.business_outlined);
}
```

### 2. Selector de Branch (Ya implementado)

```dart
// lib/modules/dashboard/presentation/home_pilot.dart
HomePracticeSelector(
  selected: model.branch,
  onChanged: model.selectBranch,
)
// Muestra: "Exóticos" para ClinicalBranch.exotic
```

### 3. Integración en App (Parcial)

```dart
// lib/core/app.dart
initialTool: model.branch == ClinicalBranch.exotic
    ? 'metabolic'  // Herramienta inicial para exóticos
    : model.branch == ClinicalBranch.production
        ? 'water'
        : 'fluids',
```

### 4. ClinicPreset (Falta Exóticos)

```dart
// lib/modules/clinic_experience/domain/clinic_experience.dart
enum ClinicPreset { 
  general, 
  smallAnimals, 
  hospital, 
  production, 
  custom 
  // ❌ FALTA: exotic
}
```

### 5. Secciones Configurables (Falta Exóticos)

```dart
// lib/modules/core/domain/section_catalog.dart
const sectionGroups = [
  SectionGroup('Atención y expedientes', [...]),
  SectionGroup('Medicamentos y herramientas', [...]),
  SectionGroup('Producción animal', ['Producción y grandes especies']),
  // ❌ FALTA: Sección para Exóticos
];
```

---

## 🏗️ Propuesta de Implementación

### Fase 1: Configuración Básica (Día 1)

#### 1.1. Añadir ClinicPreset.exotic

**Archivo:** `lib/modules/clinic_experience/domain/clinic_experience.dart`

```dart
enum ClinicPreset { 
  general, 
  smallAnimals, 
  hospital, 
  production, 
  exotic,  // ✅ Nuevo
  custom 
}
```

**Configuración de módulos visibles para exóticos:**

```dart
ClinicPreset.exotic => <String>{
  'Atención y expedientes',
  'Medicamentos y herramientas',
  'Exóticos y silvestres',  // ✅ Nueva sección
  'Administración y finanzas',
  'Equipo y comunicación',
  'Asistente IA',
  'Revisión de catálogos',
},
```

#### 1.2. Añadir Sección de Exóticos

**Archivo:** `lib/modules/core/domain/section_catalog.dart`

```dart
const sectionGroups = [
  SectionGroup('Atención y expedientes', [...]),
  SectionGroup('Medicamentos y herramientas', [...]),
  SectionGroup('Producción animal', ['Producción y grandes especies']),
  SectionGroup('Exóticos y silvestres', [  // ✅ Nuevo
    'Exóticos',
    'Ficha exótica',
    'Calculadoras exóticas',
    'Protocolos exóticos',
  ]),
  SectionGroup('Administración y finanzas', [...]),
  // ... resto
];
```

#### 1.3. Añadir Rutas para Exóticos

**Nuevas rutas a registrar:**
- `'Exóticos'` - Pantalla principal de exóticos
- `'Ficha exótica'` - Ficha clínica especializada
- `'Calculadoras exóticas'` - Calculadoras de dosificación
- `'Protocolos exóticos'` - Protocolos clínicos

---

### Fase 2: Dashboard Específico (Días 2-3)

#### 2.1. Pantalla Principal de Exóticos

**Nuevo archivo:** `lib/modules/exotic/presentation/exotic_dashboard_screen.dart`

**Estructura propuesta:**

```dart
class ExoticDashboardScreen extends StatelessWidget {
  const ExoticDashboardScreen({
    super.key,
    required this.member,
    required this.onNavigate,
  });
  
  final ClinicMembership member;
  final ValueChanged<String> onNavigate;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exóticos / Silvestres'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => onNavigate('Búsqueda exóticos'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Resumen rápido
            const ExoticSummaryPanel(),
            
            // Accesos rápidos
            Text('Accesos rápidos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            HomeModuleGrid(
              actions: [
                ('Ficha clínica', 'Ficha exótica'),
                ('Calculadoras', 'Calculadoras exóticas'),
                ('Protocolos', 'Protocolos exóticos'),
                ('Pacientes', 'Pacientes'),
              ],
              onNavigate: onNavigate,
            ),
            
            // Por especie
            const SizedBox(height: 20),
            Text('Por especie', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSpeciesCard(context, 'Aves', Icons.egg_outlined, () => onNavigate('Aves exóticas')),
                _buildSpeciesCard(context, 'Reptiles', Icons.pets_outlined, () => onNavigate('Reptiles')),
                _buildSpeciesCard(context, 'Peces', Icons.fish_outlined, () => onNavigate('Peces ornamentales')),
                _buildSpeciesCard(context, 'Mamíferos', Icons.rodent_outlined, () => onNavigate('Mamíferos pequeños')),
                _buildSpeciesCard(context, 'Anfibios', Icons.frog_outlined, () => onNavigate('Anfibios')),
                _buildSpeciesCard(context, 'Invertebrados', Icons.bug_report_outlined, () => onNavigate('Invertebrados')),
              ],
            ),
            
            // Herramientas especializadas
            const SizedBox(height: 20),
            Text('Herramientas especializadas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onNavigate('Calculadora metabólica'),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Metabólica'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onNavigate('Conversor unidades'),
                  icon: const Icon(Icons.swap_horiz_outlined),
                  label: const Text('Conversor'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onNavigate('Guía ambiental'),
                  icon: const Icon(Icons.thermostat_outlined),
                  label: const Text('Ambiental'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSpeciesCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 120,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

#### 2.2. Integración con Dashboard Existente

**Modificar:** `lib/modules/dashboard/presentation/dashboard_screen.dart`

Añadir condición para mostrar dashboard específico de exóticos:

```dart
// En el lugar donde se crea DashboardScreen
if (model.branch == ClinicalBranch.exotic) {
  ExoticDashboardScreen(
    member: auth!.active!,
    onNavigate: model.navigate,
  );
} else {
  // Dashboard normal
  DashboardScreen(...)
}
```

---

### Fase 3: Estructura de Datos en Supabase (Días 3-4)

**Nota:** Solar y Mimo (de Buffy) ya tienen acceso a Supabase. GPT sabe la organización.

#### 3.1. Tablas Propuestas

**Tabla: exotic_patients**
```sql
CREATE TABLE exotic_patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID REFERENCES clinics(id) NOT NULL,
  user_id UUID REFERENCES users(id) NOT NULL,
  
  -- Datos básicos
  name TEXT NOT NULL,
  species_type TEXT NOT NULL,  -- 'ave', 'reptil', 'pez', 'mamifero', 'anfibio', 'invertebrado'
  species VARCHAR(100),  -- Ej: 'Loro', 'Iguana', 'Goldfish'
  breed VARCHAR(100),  -- Raza o variedad
  
  -- Identificación
  age_years INTEGER,
  age_months INTEGER,
  sex TEXT,  -- 'Macho', 'Hembra', 'Desconocido'
  weight_grams INTEGER,  -- Peso en gramos (más preciso para exóticos)
  identification_mark TEXT,  -- Anilla, microchip, etc.
  
  -- Parámetros ambientales (importantes para exóticos)
  habitat_type TEXT,  -- 'Terrario', 'Acuario', 'Jaula', 'Aviario'
  temperature_min DECIMAL(5,2),  -- °C
  temperature_max DECIMAL(5,2),
  humidity_min DECIMAL(5,2),  -- %
  humidity_max DECIMAL(5,2),
  lighting_type TEXT,  -- 'Natural', 'UVB', 'LED'
  
  -- Historial
  acquisition_date DATE,
  previous_owner TEXT,
  medical_history TEXT,
  
  -- Estado
  status TEXT DEFAULT 'Activo',  -- 'Activo', 'Hospitalizado', 'Alta', 'Fallecido'
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para búsquedas rápidas
CREATE INDEX idx_exotic_patients_clinic ON exotic_patients(clinic_id);
CREATE INDEX idx_exotic_patients_species ON exotic_patients(species_type, species);
CREATE INDEX idx_exotic_patients_status ON exotic_patients(status);
```

**Tabla: exotic_species_parameters**
```sql
CREATE TABLE exotic_species_parameters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Identificación
  species_type TEXT NOT NULL,  -- 'ave', 'reptil', etc.
  species VARCHAR(100) NOT NULL,
  common_name VARCHAR(100) NOT NULL,
  scientific_name VARCHAR(100),
  
  -- Parámetros fisiológicos
  avg_lifespan_years DECIMAL(5,1),
  avg_weight_grams_min DECIMAL(8,2),
  avg_weight_grams_max DECIMAL(8,2),
  body_temperature_min DECIMAL(5,2),
  body_temperature_max DECIMAL(5,2),
  heart_rate_min INTEGER,  -- latidos por minuto
  heart_rate_max INTEGER,
  respiratory_rate_min INTEGER,  -- respiraciones por minuto
  respiratory_rate_max INTEGER,
  
  -- Parámetros ambientales ideales
  ideal_temperature_min DECIMAL(5,2),
  ideal_temperature_max DECIMAL(5,2),
  ideal_humidity_min DECIMAL(5,2),
  ideal_humidity_max DECIMAL(5,2),
  uvb_requirement TEXT,  -- 'Ninguno', 'Bajo', 'Moderado', 'Alto'
  
  -- Metabolismo (factor para calculadoras)
  metabolism_factor DECIMAL(4,2) DEFAULT 1.0,
  
  -- Notas
  notes TEXT,
  source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(species_type, species)
);

CREATE INDEX idx_exotic_species_parameters_type ON exotic_species_parameters(species_type);
```

**Tabla: exotic_drug_contraindications**
```sql
CREATE TABLE exotic_drug_contraindications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  drug_id UUID NOT NULL,  -- Referencia a tabla de fármacos
  species_type TEXT NOT NULL,
  species VARCHAR(100),
  
  -- Información de contraindicación
  contraindication_level TEXT NOT NULL,  -- 'Absoluta', 'Relativa', 'Precaución'
  reason TEXT NOT NULL,
  alternative_drugs TEXT[],
  
  -- Evidencia
  source TEXT,
  evidence_level TEXT,  -- 'Alto', 'Moderado', 'Bajo'
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(drug_id, species_type, species)
);

CREATE INDEX idx_exotic_drug_contraindications ON exotic_drug_contraindications(drug_id, species_type);
```

#### 3.2. Datos Iniciales de Especies

**Ejemplos de especies a incluir:**

```sql
-- Aves
INSERT INTO exotic_species_parameters (species_type, species, common_name, avg_lifespan_years, metabolism_factor) VALUES
('ave', 'Psittaciformes', 'Loro', 50, 1.2),
('ave', 'Canaria', 'Canario', 10, 1.5),
('ave', 'Periquito', 'Periquito australiano', 15, 1.4);

-- Reptiles
INSERT INTO exotic_species_parameters (species_type, species, common_name, avg_lifespan_years, metabolism_factor) VALUES
('reptil', 'Iguana', 'Iguana verde', 20, 0.8),
('reptil', 'Testudo', 'Tortuga de tierra', 50, 0.7),
('reptil', 'Python', 'Pitón real', 30, 0.8);

-- Peces
INSERT INTO exotic_species_parameters (species_type, species, common_name, avg_lifespan_years, metabolism_factor) VALUES
('pez', 'Carassius', 'Goldfish', 15, 0.5),
('pez', 'Betta', 'Betta splendens', 3, 0.6),
('pez', 'Discus', 'Discus', 10, 0.5);
```

---

### Fase 4: Calculadoras Especializadas (Días 4-5)

#### 4.1. Calculadora Metabólica

**Fórmula:**
```
Dosis ajustada = Dosis estándar × Factor de metabolismo × Factor de especie
```

**Ejemplo de implementación:**

```dart
class ExoticMetabolicCalculator {
  static double calculateDose({
    required double standardDose,  // mg/kg
    required double weightGrams,  // gramos
    required String speciesType,
    required String species,
    required double metabolismFactor,
  }) {
    // Convertir gramos a kg
    final weightKg = weightGrams / 1000;
    
    // Aplicar factor de metabolismo
    final adjustedDose = standardDose * metabolismFactor;
    
    // Calcular dosis total
    final totalDose = adjustedDose * weightKg;
    
    return totalDose;
  }
  
  static String getMetabolismFactor(String speciesType, String species) {
    // Valores por defecto
    switch (speciesType) {
      case 'ave': return '1.2 - 1.5';
      case 'reptil': return '0.7 - 0.8';
      case 'pez': return '0.5 - 0.6';
      case 'mamifero': return '1.0 - 1.2';
      default: return '1.0';
    }
  }
}
```

#### 4.2. Conversor de Unidades

**Conversiones comunes para exóticos:**
- mg/kg ↔ µg/g
- mL ↔ gotas (1 mL = 20 gotas)
- mg ↔ µg
- L ↔ mL

#### 4.3. Calculadora de Volumen de Agua (para peces)

```dart
class AquaticVolumeCalculator {
  static double calculateDrugVolume({
    required double drugConcentration,  // mg/mL
    required double tankVolumeLiters,  // litros
    required double desiredConcentration,  // mg/L
  }) {
    // Volumen de fármaco en mL = (Concentración deseada × Volumen tanque) / Concentración fármaco
    final volumeMl = (desiredConcentration * tankVolumeLiters) / drugConcentration;
    return volumeMl;
  }
}
```

---

### Fase 5: Protocolos Clínicos (Días 5-6)

#### 5.1. Protocolos por Especie y Enfermedad

**Estructura de protocolos:**

```dart
class ExoticProtocol {
  final String id;
  final String speciesType;
  final String species;
  final String disease;
  final String severity;  // 'Leve', 'Moderado', 'Severo'
  final List<ProtocolStep> steps;
  final String notes;
  final String source;
  
  ExoticProtocol({...});
}

class ProtocolStep {
  final int order;
  final String action;
  final String? drug;
  final String? dose;
  final String? route;  // 'Oral', 'Inyectable', 'Tópico', 'En agua'
  final String? frequency;
  final int? durationDays;
  final String? notes;
}
```

**Ejemplo de protocolo:**

```yaml
# Protocolo para ictioftiriasis en peces
- especie: pez
  enfermedad: Ictioftiriasis (punto blanco)
  severidad: Leve
  pasos:
    - orden: 1
      accion: Aumentar temperatura a 30-32°C
      duracion: 7 días
    - orden: 2
      accion: Tratamiento con formalina
      farmaco: Formalina al 37%
      dosis: 0.25 mL/10L
      frecuencia: Cada 24 horas
      duracion: 3 días
      via: En agua
    - orden: 3
      accion: Cambio de agua parcial
      frecuencia: Cada 48 horas
      notas: 30-50% del volumen
```

---

## 📊 Diagrama de Integración

```
┌─────────────────────────────────────────────────────────────┐
│                    EXÓTICOS / SILVESTRES                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│  │  Dashboard   │    │ Ficha Clínica│    │ Calculadoras │ │
│  │  Principal   │    │  Especializada│    │ Especializadas│ │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘ │
│         │                  │                  │          │
│         ▼                  ▼                  ▼          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                SUPABASE (Solar/Mimo)                 │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │ │
│  │  │exotic_patients│  │exotic_species │  │drug_contra │ │ │
│  │  │              │  │_parameters   │  │indications  │ │ │
│  │  └──────────────┘  └──────────────┘  └────────────┘ │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              PROTOCOLOS CLÍNICOS                    │ │
│  │  - Por especie (aves, reptiles, peces, etc.)         │ │
│  │  - Por enfermedad                                      │ │
│  │  - Por severidad                                       │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎨 Diseño Visual Propuesto

### Pantalla Principal (Dashboard)

```
┌─────────────────────────────────────────────────────────────┐
│  Exóticos / Silvestres                    [🔍 Buscar]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📊 RESUMEN RÁPIDO                                         │
│  ┌──────────┬──────────┬──────────┬──────────┐             │
│  │  Pacientes│   Aves   │ Reptiles │   Peces   │             │
│  │     24    │    12    │     8    │     4    │             │
│  └──────────┴──────────┴──────────┴──────────┘             │
│                                                             │
│  🚀 ACCESOS RÁPIDOS                                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │Ficha     │ │Calculador│ │Protocolos│ │Pacientes │      │
│  │Clínica   │ │as        │ │          │ │          │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│                                                             │
│  🐾 POR ESPECIE                                            │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐          │
│  │ 🦜 │ │ 🦎 │ │ 🐟 │ │ 🐹 │ │ 🐸 │ │ 🕷️ │          │
│  │Aves │ │Reptil│ │Peces│ │Mamífer│ │Anfibio│ │Invert.│          │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘          │
│                                                             │
│  🔧 HERRAMIENTAS ESPECIALIZADAS                            │
│  [Metabólica] [Conversor] [Ambiental]                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Ficha Clínica de Exóticos

```
┌─────────────────────────────────────────────────────────────┐
│  ✏️ FICHA CLÍNICA - EXÓTICOS                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  DATOS BÁSICOS                                             │
│  Nombre: ________________  Especie: [Aves ▼]               │
│  Raza: ___________________  Sexo: [□ M □ H □ D]            │
│  Edad: ___ años ___ meses   Peso: ____ gramos               │
│  Identificación: _______________________________            │
│                                                             │
│  PARÁMETROS AMBIENTALES                                    │
│  Hábitat: [Terrario ▼]  Temp: ___-___°C  Hum: ___-___%      │
│  Iluminación: [UVB ▼]  Espacio: ___________________       │
│                                                             │
│  HISTORIAL                                                │
│  Adquisición: ___________  Propietario anterior: ________  │
│  Alimentación: _______________________________________     │
│  Suplementos: ________________________________________     │
│  Tratamientos previos: __________________________________    │
│                                                             │
│  [GUARDAR] [CANCELAR]                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## ⏱️ Cronograma de Implementación

| Fase | Tarea | Duración | Dependencias | Responsable |
|------|-------|----------|--------------|-------------|
| 1 | Configuración básica (ClinicPreset, sectionGroups) | 1 día | Ninguna | Mistralin |
| 2 | Dashboard específico para exóticos | 2 días | Fase 1 | Mistralin |
| 3 | Estructura de datos en Supabase | 2 días | Solar/Mimo (acceso) | Mistralin + Buffy |
| 4 | Calculadoras especializadas | 2 días | Fase 3 | Mistralin |
| 5 | Protocolos clínicos | 2 días | Fase 3 | Mistralin |
| 6 | Pruebas y validación | 2 días | Todas | Mistralin + CodeRabbit |
| **Total** | | **11 días** | | |

---

## 🤝 Coordinación con Otros Modelos

### Para Claude (Sonnet 5.5):
- ¿Puedes revisar la estructura de porcinos y dar feedback sobre la propuesta de exóticos?
- ¿Quieres colaborar en las calculadoras de dosificación?
- ¿Necesitas que la estructura de exóticos sea compatible con tu módulo de producción?

### Para GPT (Codex/Sol):
- ¿Puedes ayudar con la organización de datos en Supabase? (Solar y Mimo ya tienen acceso)
- ¿Tienes información sobre la estructura actual de Supabase para otras especies?
- ¿Puedes colaborar con la base de datos de fármacos para exóticos?

### Para Buffy (Codebuff):
- ¿Puedes revisar la integración con CI/CD para el módulo de exóticos?
- ¿Necesitas que el dashboard de exóticos siga algún patrón específico?

### Para CodeRabbit:
- Revisión de código cuando esté listo
- Validación de pruebas unitarias

---

## 📌 Siguientes Pasos Inmediatos

1. **Hoy (Día 1):**
   - Crear PR con configuración básica (ClinicPreset.exotic, sectionGroups)
   - Obtener feedback de otros modelos
   - Empezar con el dashboard específico

2. **Mañana (Día 2):**
   - Terminar implementación del dashboard
   - Coordinar con Solar/Mimo para estructura de Supabase
   - Crear tablas iniciales

3. **Día 3:**
   - Implementar calculadoras básicas
   - Cargar datos iniciales de especies
   - Crear primeros protocolos

---

## 📚 Referencias

- **Código existente:** `ClinicalBranch.exotic` ya está definido
- **Supabase:** Solar y Mimo (Buffy) tienen acceso
- **Patrón a seguir:** Módulo de porcinos de Claude
- **Documentación:** `exoticos-silvestres-propuesta-20261106.md`

---

## ✅ Checklist de Validación

- [ ] ClinicPreset.exotic añadido
- [ ] Sección 