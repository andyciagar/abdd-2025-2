#!/bin/bash

# ============================================
# SCRIPT DE CALIFICACIÓN AUTOMÁTICA - TODOS LOS ESTUDIANTES
# Califica solo la arquitectura (100 pts)
# La replicación se valida con capturas de pantalla
# ============================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Directorio de resultados
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%S-05:00")
RESULTS_DIR="resultados_${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"

# Arrays para acumular resultados
declare -a ESTUDIANTES=()
TOTAL_ESTUDIANTES=0
APROBADOS=0
REPROBADOS=0
SUMA_CALIFICACIONES=0

# ============================================
# Banner
# ============================================

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║    SISTEMA DE CALIFICACIÓN AUTOMÁTICA MASIVA - ABDD          ║"
    echo "║    Replicación Bidireccional con SymmetricDS                 ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BLUE}Este script califica la ARQUITECTURA (100 pts)${NC}"
    echo -e "${YELLOW}La replicación se valida con capturas de pantalla (ver README)${NC}"
    echo ""
    echo -e "${YELLOW}Resultados en: ${BOLD}$RESULTS_DIR/${NC}"
    echo ""
}

# ============================================
# Calificar un estudiante
# ============================================

calificar_estudiante() {
    local branch=$1
    local student_name=""
    local student_id=""
    
    # Extraer información
    if [[ $branch =~ student/(.+)_(.+)_([0-9]+) ]]; then
        local nombre="${BASH_REMATCH[1]}"
        local apellido="${BASH_REMATCH[2]}"
        student_id="${BASH_REMATCH[3]}"
        student_name="${nombre} ${apellido}"
    else
        student_name="Desconocido"
        student_id="0000000000"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Calificando: ${GREEN}$student_name${NC} ${BLUE}($student_id)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Cambiar a la rama del estudiante
    if ! git checkout "$branch" > /dev/null 2>&1; then
        echo -e "${RED}✗ Error: No se pudo cambiar a la rama $branch${NC}"
        return 1
    fi
    
    # Variables de puntuación (80 pts automático + 20 pts manual)
    local docker_compose_pts=0
    local contenedores_pts=0
    local bd_funcionamiento_pts=0
    local symmetricds_pts=0
    local total_pts=0
    local tests_passed=0
    local tests_total=14
    
    # 20 puntos manuales (replication-proofs)
    local manual_pts=0
    local manual_max=20
    
    # ========== 1. DOCKER COMPOSE (25 pts) ==========
    echo -e "${YELLOW}[1/4]${NC} Validando Docker Compose..."
    
    # 1.1 Archivo existe (8pts)
    if [ -f "docker-compose.yml" ]; then
        ((docker_compose_pts+=8))
        ((tests_passed++))
        echo -e "${GREEN}  ✓ Archivo existe (+8pts)${NC}"
        
        # 1.2 Sintaxis válida (8pts)
        if docker compose config > /dev/null 2>&1; then
            ((docker_compose_pts+=8))
            ((tests_passed++))
            echo -e "${GREEN}  ✓ Sintaxis YAML válida (+8pts)${NC}"
            
            # 1.3 4 servicios (9pts)
            local config_output=$(docker compose config 2>/dev/null)
            local services_pts=0
            
            if echo "$config_output" | grep -q "postgres-america:"; then
                ((services_pts+=2))
                ((tests_passed++))
            fi
            
            if echo "$config_output" | grep -q "mysql-europe:"; then
                ((services_pts+=2))
                ((tests_passed++))
            fi
            
            if echo "$config_output" | grep -q "symmetricds-america:"; then
                ((services_pts+=3))
                ((tests_passed++))
            fi
            
            if echo "$config_output" | grep -q "symmetricds-europe:"; then
                ((services_pts+=2))
                ((tests_passed++))
            fi
            
            ((docker_compose_pts+=services_pts))
            echo -e "${GREEN}  ✓ Servicios definidos (+${services_pts}pts)${NC}"
        else
            echo -e "${RED}  ✗ Sintaxis YAML inválida (0pts)${NC}"
        fi
    else
        echo -e "${RED}  ✗ Archivo no existe (0pts)${NC}"
    fi
    
    echo -e "${BLUE}  Subtotal: ${BOLD}$docker_compose_pts / 25 pts${NC}"
    
    # ========== 2. CONTENEDORES (20 pts) ==========
    echo -e "${YELLOW}[2/4]${NC} Levantando y validando contenedores..."
    
    # Limpiar ambiente
    docker compose down -v > /dev/null 2>&1 || true
    
    if docker compose up -d > /dev/null 2>&1; then
        echo -e "${BLUE}  Esperando 60 segundos...${NC}"
        sleep 60
        
        # 2.1 PostgreSQL (5pts)
        if docker compose ps | grep -q "postgres-america.*Up"; then
            ((contenedores_pts+=5))
            ((tests_passed++))
            echo -e "${GREEN}  ✓ postgres-america corriendo (+5pts)${NC}"
        else
            echo -e "${RED}  ✗ postgres-america no corriendo (0pts)${NC}"
        fi
        
        # 2.2 MySQL (5pts)
        if docker compose ps | grep -q "mysql-europe.*Up"; then
            ((contenedores_pts+=5))
            ((tests_passed++))
            echo -e "${GREEN}  ✓ mysql-europe corriendo (+5pts)${NC}"
        else
            echo -e "${RED}  ✗ mysql-europe no corriendo (0pts)${NC}"
        fi
        
        # 2.3 SymmetricDS América (5pts)
        if docker compose ps | grep -q "symmetricds-america.*Up"; then
            ((contenedores_pts+=5))
            ((tests_passed++))
            echo -e "${GREEN}  ✓ symmetricds-america corriendo (+5pts)${NC}"
        else
            echo -e "${RED}  ✗ symmetricds-america no corriendo (0pts)${NC}"
        fi
        
        # 2.4 SymmetricDS Europa (5pts)
        if docker compose ps | grep -q "symmetricds-europe.*Up"; then
            ((contenedores_pts+=5))
            ((tests_passed++))
            echo -e "${GREEN}  ✓ symmetricds-europe corriendo (+5pts)${NC}"
        else
            echo -e "${RED}  ✗ symmetricds-europe no corriendo (0pts)${NC}"
        fi
    else
        echo -e "${RED}  ✗ Error al levantar servicios (0pts)${NC}"
    fi
    
    echo -e "${BLUE}  Subtotal: ${BOLD}$contenedores_pts / 20 pts${NC}"
    
    # ========== 3. BASES DE DATOS (15 pts) ==========
    echo -e "${YELLOW}[3/4]${NC} Validando bases de datos..."
    
    # 3.1 Conexión PostgreSQL (5pts)
    if docker exec postgres-america psql -U symmetricds -d globalshop -c "SELECT 1;" > /dev/null 2>&1; then
        ((bd_funcionamiento_pts+=5))
        ((tests_passed++))
        echo -e "${GREEN}  ✓ Conexión PostgreSQL (+5pts)${NC}"
    else
        echo -e "${RED}  ✗ Sin conexión PostgreSQL (0pts)${NC}"
    fi
    
    # 3.2 Tablas en PostgreSQL (5pts)
    local pg_tables=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('products','inventory','customers','promotions');" 2>/dev/null | tr -d ' ')
    if [ "$pg_tables" = "4" ]; then
        ((bd_funcionamiento_pts+=5))
        ((tests_passed++))
        echo -e "${GREEN}  ✓ 4 tablas en PostgreSQL (+5pts)${NC}"
    else
        echo -e "${RED}  ✗ Tablas faltantes: $pg_tables/4 (0pts)${NC}"
    fi
    
    # 3.3 Conexión MySQL (5pts)
    if docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e "SELECT 1;" > /dev/null 2>&1; then
        ((bd_funcionamiento_pts+=5))
        ((tests_passed++))
        echo -e "${GREEN}  ✓ Conexión MySQL (+5pts)${NC}"
    else
        echo -e "${RED}  ✗ Sin conexión MySQL (0pts)${NC}"
    fi
    
    echo -e "${BLUE}  Subtotal: ${BOLD}$bd_funcionamiento_pts / 15 pts${NC}"
    
    # ========== 4. SYMMETRICDS (20 pts) ==========
    echo -e "${YELLOW}[4/4]${NC} Validando SymmetricDS..."
    
    # 4.1 Tablas SymmetricDS en PostgreSQL (8pts)
    local sym_tables=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'sym_%';" 2>/dev/null | tr -d ' ')
    if [ "$sym_tables" -gt 30 ]; then
        ((symmetricds_pts+=8))
        ((tests_passed++))
        echo -e "${GREEN}  ✓ Tablas SymmetricDS en PostgreSQL: $sym_tables (+8pts)${NC}"
    else
        echo -e "${RED}  ✗ Tablas SymmetricDS insuficientes: $sym_tables (0pts)${NC}"
    fi
    
    # 4.2 Tablas SymmetricDS en MySQL (8pts)
    local sym_tables_mysql=$(docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='globalshop' AND table_name LIKE 'sym_%';" 2>/dev/null)
    if [ "$sym_tables_mysql" -gt 30 ]; then
        ((symmetricds_pts+=8))
        ((tests_passed++))
        echo -e "${GREEN}  ✓ Tablas SymmetricDS en MySQL: $sym_tables_mysql (+8pts)${NC}"
    else
        echo -e "${RED}  ✗ Tablas SymmetricDS insuficientes: $sym_tables_mysql (0pts)${NC}"
    fi
    
    # 4.3 Grupos de nodos configurados (4pts)
    local node_groups=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM sym_node_group;" 2>/dev/null | tr -d ' ')
    if [ "$node_groups" -ge 2 ]; then
        ((symmetricds_pts+=4))
        ((tests_passed++))
        echo -e "${GREEN}  ✓ Grupos de nodos: $node_groups (+4pts)${NC}"
    else
        echo -e "${RED}  ✗ Grupos insuficientes: $node_groups (0pts)${NC}"
    fi
    
    echo -e "${BLUE}  Subtotal: ${BOLD}$symmetricds_pts / 20 pts${NC}"
    
    # ========== 5. VERIFICAR CARPETA REPLICATION-PROOFS (0 pts - solo info) ==========
    echo ""
    echo -e "${YELLOW}[INFO]${NC} Verificando carpeta de evidencias..."
    if [ -d "replication-proofs" ]; then
        local num_files=$(ls -1 replication-proofs/*.png replication-proofs/*.jpg 2>/dev/null | wc -l)
        echo -e "${GREEN}  ✓ Carpeta replication-proofs existe${NC}"
        echo -e "${BLUE}  ℹ Archivos encontrados: $num_files${NC}"
        echo -e "${YELLOW}  → Calificación manual: 0-20 pts (revisar capturas)${NC}"
    else
        echo -e "${RED}  ✗ Carpeta replication-proofs NO existe${NC}"
        echo -e "${YELLOW}  → Calificación manual: 0 pts${NC}"
    fi
    
    # ========== CALCULAR TOTAL ==========
    total_pts=$((docker_compose_pts + contenedores_pts + bd_funcionamiento_pts + symmetricds_pts))
    local percentage=$((total_pts * 100 / 100))
    
    # Determinar nota
    local nota=""
    local aprobado="false"
    if [ $percentage -ge 90 ]; then
        nota="A - Excelente"
        aprobado="true"
        ((APROBADOS++))
    elif [ $percentage -ge 80 ]; then
        nota="B - Bueno"
        aprobado="true"
        ((APROBADOS++))
    elif [ $percentage -ge 70 ]; then
        nota="C - Aceptable"
        aprobado="true"
        ((APROBADOS++))
    elif [ $percentage -ge 60 ]; then
        nota="D - Suficiente"
        aprobado="true"
        ((APROBADOS++))
    else
        nota="F - Insuficiente"
        aprobado="false"
        ((REPROBADOS++))
    fi
    
    echo ""
    echo -e "${BOLD}┌────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│ ARQUITECTURA: $total_pts / 80 pts${NC}"
    echo -e "${BOLD}│ REPLICACIÓN:  manual / 20 pts${NC}"
    echo -e "${BOLD}├────────────────────────────────────────────┤${NC}"
    echo -e "${BOLD}│ SUBTOTAL:     $total_pts / 80 pts - ${nota}${NC}"
    echo -e "${BOLD}└────────────────────────────────────────────┘${NC}"
    echo -e "${YELLOW}Nota: Revisar carpeta replication-proofs/ para los 20 pts restantes${NC}"
    echo ""
    
    ((SUMA_CALIFICACIONES+=total_pts))
    
    # Guardar para JSON
    ESTUDIANTES+=("{
      \"nombre\": \"$student_name\",
      \"cedula\": \"$student_id\",
      \"rama\": \"$branch\",
      \"calificacion\": {
        \"arquitectura\": $total_pts,
        \"replicacion_manual\": \"pendiente\",
        \"total\": \"$total_pts + manual\",
        \"nota_arquitectura\": \"$nota\",
        \"aprobado\": $aprobado
      },
      \"desglose\": {
        \"docker_compose\": { \"obtenido\": $docker_compose_pts, \"maximo\": 25 },
        \"contenedores\": { \"obtenido\": $contenedores_pts, \"maximo\": 20 },
        \"bases_datos\": { \"obtenido\": $bd_funcionamiento_pts, \"maximo\": 15 },
        \"symmetricds\": { \"obtenido\": $symmetricds_pts, \"maximo\": 20 },
        \"replicacion_manual\": { \"obtenido\": \"revisar_replication-proofs\", \"maximo\": 20 }
      },
      \"detalles\": {
        \"tests_pasados\": $tests_passed,
        \"tests_totales\": $tests_total,
        \"tablas_negocio\": 4,
        \"tablas_symmetricds_pg\": $sym_tables,
        \"tablas_symmetricds_mysql\": $sym_tables_mysql,
        \"servicios_docker\": 4,
        \"carpeta_evidencias\": \"replication-proofs/\"
      }
    }")
    
    # Reporte individual
    cat > "$RESULTS_DIR/${student_name// /_}_${student_id}.log" << EOF
============================================================
REPORTE INDIVIDUAL - ARQUITECTURA
============================================================
Estudiante: $student_name
Cédula: $student_id
Rama: $branch
Fecha: $(date)

CALIFICACIÓN ARQUITECTURA (AUTOMÁTICA):
  Subtotal: $total_pts / 80
  Nota parcial: $nota
  Estado: $([ "$aprobado" = "true" ] && echo "APROBADO ✓" || echo "REPROBADO ✗")

DESGLOSE AUTOMÁTICO:
  1. Docker Compose (estructura)     $docker_compose_pts / 25
  2. Contenedores (ejecución)        $contenedores_pts / 20
  3. Bases de Datos (funcionamiento) $bd_funcionamiento_pts / 15
  4. SymmetricDS (configuración)     $symmetricds_pts / 20

CALIFICACIÓN MANUAL (PENDIENTE):
  5. Evidencias de Replicación       ?? / 20
     → Revisar carpeta: replication-proofs/
     → 5 capturas de pantalla requeridas
     → Ver README.md sección "Evidencias"

CALIFICACIÓN FINAL:
  Total = Arquitectura (80) + Replicación Manual (20) = ?? / 100

ESTADÍSTICAS:
  Tests pasados: $tests_passed / $tests_total
  Porcentaje: ${percentage}%

IMPORTANTE:
  La replicación bidireccional (operaciones INSERT, UPDATE, DELETE)
  debe demostrarse con capturas de pantalla según README.md
============================================================
EOF
    
    # Limpiar
    docker compose down -v > /dev/null 2>&1 || true
    git checkout main > /dev/null 2>&1
}

# ============================================
# Generar reportes consolidados
# ============================================

generate_consolidated_reports() {
    local promedio=0
    if [ $TOTAL_ESTUDIANTES -gt 0 ]; then
        promedio=$((SUMA_CALIFICACIONES / TOTAL_ESTUDIANTES))
    fi
    
    local porcentaje_aprobados="0.00"
    if [ $TOTAL_ESTUDIANTES -gt 0 ]; then
        porcentaje_aprobados=$(printf "%.2f" $(echo "$APROBADOS * 100 / $TOTAL_ESTUDIANTES" | bc -l))
    fi
    
    # ========== JSON ==========
    local estudiantes_json=$(IFS=,; echo "${ESTUDIANTES[*]}")
    
    cat > "$RESULTS_DIR/calificaciones.json" << EOF
{
  "fecha": "$TIMESTAMP_ISO",
  "estudiantes": [
    $estudiantes_json
  ],
  "estadisticas": {
    "total_estudiantes": $TOTAL_ESTUDIANTES,
    "aprobados": $APROBADOS,
    "reprobados": $REPROBADOS,
    "promedio": $promedio,
    "porcentaje_aprobados": $porcentaje_aprobados
  },
  "nota_importante": "La replicación se valida con capturas de pantalla (ver README.md)"
}
EOF
    
    # ========== CSV ==========
    cat > "$RESULTS_DIR/calificaciones.csv" << EOF
nombre,cedula,rama,docker_compose,contenedores,bases_datos,symmetricds,total,nota,aprobado
EOF
    
    for branch in $(git branch -r | grep 'origin/student/' | sed 's/origin\///'); do
        if [[ $branch =~ student/(.+)_(.+)_([0-9]+) ]]; then
            local sname="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
            local sid="${BASH_REMATCH[3]}"
            
            if [ -f "$RESULTS_DIR/${sname// /_}_${sid}.log" ]; then
                local total=$(grep "Total:" "$RESULTS_DIR/${sname// /_}_${sid}.log" | awk '{print $2}' | cut -d'/' -f1 | xargs)
                local nota=$(grep "Nota:" "$RESULTS_DIR/${sname// /_}_${sid}.log" | cut -d':' -f2 | xargs)
                local aprobado=$(grep "Estado:" "$RESULTS_DIR/${sname// /_}_${sid}.log" | grep -q "APROBADO" && echo "true" || echo "false")
                
                local dc=$(grep "Docker Compose" "$RESULTS_DIR/${sname// /_}_${sid}.log" | grep ")" | awk '{print $5}' | cut -d'/' -f1 | xargs)
                local cont=$(grep "Contenedores" "$RESULTS_DIR/${sname// /_}_${sid}.log" | grep ")" | awk '{print $3}' | cut -d'/' -f1 | xargs)
                local db=$(grep "Bases de Datos" "$RESULTS_DIR/${sname// /_}_${sid}.log" | grep ")" | awk '{print $4}' | cut -d'/' -f1 | xargs)
                local sym=$(grep "SymmetricDS" "$RESULTS_DIR/${sname// /_}_${sid}.log" | grep ")" | awk '{print $3}' | cut -d'/' -f1 | xargs)
                
                echo "\"$sname\",$sid,$branch,$dc,$cont,$db,$sym,$total,\"$nota\",$aprobado" >> "$RESULTS_DIR/calificaciones.csv"
            fi
        fi
    done
    
    # ========== RESUMEN ==========
    cat > "$RESULTS_DIR/RESUMEN.txt" << EOF
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         REPORTE CONSOLIDADO DE CALIFICACIONES                ║
║         Examen: Replicación Bidireccional SymmetricDS        ║
║         Evaluación: ARQUITECTURA (100 puntos)                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

Fecha: $(date)
Generado por: calificar_todos.sh

NOTA IMPORTANTE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Esta calificación evalúa solo la ARQUITECTURA (100 pts).
  
  La REPLICACIÓN BIDIRECCIONAL debe demostrarse con capturas
  de pantalla mostrando:
    • INSERT en PostgreSQL → aparece en MySQL
    • INSERT en MySQL → aparece en PostgreSQL
    • UPDATE en ambas direcciones
    • DELETE en ambas direcciones
  
  Ver README.md sección "Evidencias de Replicación"

ESTADÍSTICAS GENERALES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Total de estudiantes:       $TOTAL_ESTUDIANTES
  Aprobados (≥60):            $APROBADOS
  Reprobados (<60):           $REPROBADOS
  Promedio general:           $promedio / 100
  % Aprobación:               ${porcentaje_aprobados}%

DISTRIBUCIÓN DE CALIFICACIONES (Solo Arquitectura):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    for logfile in "$RESULTS_DIR"/*.log; do
        if [ -f "$logfile" ] && [[ "$logfile" != *"RESUMEN"* ]]; then
            local nombre=$(basename "$logfile" .log | sed 's/_/ /g')
            local total=$(grep "Total:" "$logfile" | awk '{print $2}' | cut -d'/' -f1 | xargs)
            local nota=$(grep "Nota:" "$logfile" | cut -d':' -f2 | xargs)
            echo "  • $nombre: $total pts - $nota" >> "$RESULTS_DIR/RESUMEN.txt"
        fi
    done
    
    cat >> "$RESULTS_DIR/RESUMEN.txt" << EOF

ARCHIVOS GENERADOS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  → calificaciones.json    (JSON consolidado)
  → calificaciones.csv     (CSV para Excel/Sheets)
  → RESUMEN.txt            (Este archivo)
  → *.log                  (Reportes individuales)
============================================================
EOF
}

# ============================================
# Main
# ============================================

main() {
    print_banner
    
    # Verificar que estamos en main
    local current_branch=$(git branch --show-current)
    if [ "$current_branch" != "main" ]; then
        echo -e "${RED}Error: Ejecutar desde rama main${NC}"
        exit 1
    fi
    
    # Actualizar ramas
    echo -e "${BLUE}Actualizando ramas...${NC}"
    git fetch --all > /dev/null 2>&1
    
    # Obtener ramas de estudiantes
    local student_branches=($(git branch -r | grep 'origin/student/' | sed 's/origin\///'))
    TOTAL_ESTUDIANTES=${#student_branches[@]}
    
    if [ $TOTAL_ESTUDIANTES -eq 0 ]; then
        echo -e "${RED}No hay ramas student/*${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Encontradas $TOTAL_ESTUDIANTES rama(s)${NC}"
    echo ""
    for branch in "${student_branches[@]}"; do
        echo -e "  • $branch"
    done
    echo ""
    
    read -p "Presiona ENTER para comenzar..."
    echo ""
    
    # Calificar cada estudiante
    local counter=1
    for branch in "${student_branches[@]}"; do
        echo ""
        echo -e "${CYAN}${BOLD}[Estudiante $counter / $TOTAL_ESTUDIANTES]${NC}"
        calificar_estudiante "$branch"
        ((counter++))
    done
    
    # Reportes consolidados
    echo ""
    echo -e "${BLUE}${BOLD}Generando reportes...${NC}"
    generate_consolidated_reports
    
    # Resumen final
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║         ✓ CALIFICACIÓN COMPLETADA                            ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Estudiantes: ${BOLD}$TOTAL_ESTUDIANTES${NC} | ${GREEN}Aprobados: ${BOLD}$APROBADOS${NC} | ${RED}Reprobados: ${BOLD}$REPROBADOS${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}📁 Resultados: ${YELLOW}$RESULTS_DIR/${NC}"
    echo ""
    echo -e "${BLUE}Archivos:${NC}"
    echo -e "  → ${CYAN}calificaciones.json${NC}  (JSON)"
    echo -e "  → ${CYAN}calificaciones.csv${NC}   (CSV)"
    echo -e "  → ${CYAN}RESUMEN.txt${NC}          (Resumen)"
    echo -e "  → ${CYAN}*.log${NC}                (Individuales)"
    echo ""
    
    # Mostrar JSON
    echo -e "${YELLOW}${BOLD}📄 JSON Generado:${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    cat "$RESULTS_DIR/calificaciones.json"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    echo ""
}

main
exit 0
