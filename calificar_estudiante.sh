#!/bin/bash

# ============================================
# SCRIPT DE CALIFICACIÓN AUTOMÁTICA
# Genera: JSON, CSV, TXT, LOG
# ============================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Variables de puntuación
DOCKER_COMPOSE_POINTS=0
DOCKER_COMPOSE_MAX=20

CONTAINERS_POINTS=0
CONTAINERS_MAX=20

DATABASES_POINTS=0
DATABASES_MAX=15

SYMMETRICDS_POINTS=0
SYMMETRICDS_MAX=15

REPLICATION_POINTS=0
REPLICATION_MAX=30

TOTAL_SCORE=0
MAX_SCORE=100

# Variables de detalles
TESTS_PASSED=0
TESTS_TOTAL=0

# Información del estudiante (extraída de la rama)
STUDENT_NAME=""
STUDENT_ID=""
BRANCH_NAME=""

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%S-05:00")

# Directorio de salida
OUTPUT_DIR="calificaciones_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# ============================================
# Funciones auxiliares
# ============================================

print_header() {
    echo "" | tee -a "$OUTPUT_DIR/log.txt"
    echo -e "${CYAN}============================================${NC}" | tee -a "$OUTPUT_DIR/log.txt"
    echo -e "${CYAN}${BOLD}$1${NC}" | tee -a "$OUTPUT_DIR/log.txt"
    echo -e "${CYAN}============================================${NC}" | tee -a "$OUTPUT_DIR/log.txt"
}

print_test() {
    echo -n "  → $1 ... " | tee -a "$OUTPUT_DIR/log.txt"
}

print_pass() {
    local points=$1
    echo -e "${GREEN}✓ (+${points}pts)${NC}" | tee -a "$OUTPUT_DIR/log.txt"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ (0pts)${NC}" | tee -a "$OUTPUT_DIR/log.txt"
    if [ ! -z "$1" ]; then
        echo -e "    ${YELLOW}  Razón: $1${NC}" | tee -a "$OUTPUT_DIR/log.txt"
    fi
}

print_info() {
    echo -e "${YELLOW}ℹ  $1${NC}" | tee -a "$OUTPUT_DIR/log.txt"
}

# ============================================
# Extraer información del estudiante
# ============================================

extract_student_info() {
    BRANCH_NAME=$(git branch --show-current)
    
    if [[ $BRANCH_NAME =~ student/(.+)_(.+)_([0-9]+) ]]; then
        local nombre="${BASH_REMATCH[1]}"
        local apellido="${BASH_REMATCH[2]}"
        STUDENT_ID="${BASH_REMATCH[3]}"
        STUDENT_NAME="${nombre} ${apellido}"
    else
        STUDENT_NAME="Desconocido"
        STUDENT_ID="0000000000"
    fi
}

# ============================================
# SECCIÓN 1: Docker Compose (20 puntos)
# ============================================

validate_docker_compose() {
    print_header "SECCIÓN 1: DOCKER COMPOSE (20 puntos)"
    local section_score=0
    
    ((TESTS_TOTAL+=4))
    
    # Test 1: Archivo existe (5pts)
    print_test "1.1. Archivo docker-compose.yml existe"
    if [ -f "docker-compose.yml" ]; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Archivo docker-compose.yml no encontrado"
        DOCKER_COMPOSE_POINTS=$section_score
        return 1
    fi
    
    # Test 2: Sintaxis YAML válida (5pts)
    print_test "1.2. Sintaxis YAML es válida"
    if docker compose config > /dev/null 2>&1; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Error en sintaxis YAML"
        DOCKER_COMPOSE_POINTS=$section_score
        return 1
    fi
    
    # Test 3: 4 servicios definidos (8pts)
    local services_count=0
    print_test "1.3. Servicios postgres-america, mysql-europe definidos"
    if docker compose config 2>/dev/null | grep -q "postgres-america:" && \
       docker compose config 2>/dev/null | grep -q "mysql-europe:"; then
        print_pass 4
        ((section_score+=4))
        ((services_count+=2))
    else
        print_fail "Servicios de BD no encontrados"
    fi
    
    print_test "1.4. Servicios SymmetricDS definidos"
    if docker compose config 2>/dev/null | grep -q "symmetricds-america:" && \
       docker compose config 2>/dev/null | grep -q "symmetricds-europe:"; then
        print_pass 4
        ((section_score+=4))
        ((services_count+=2))
    else
        print_fail "Servicios SymmetricDS no encontrados"
    fi
    
    # Test 4: Red y volúmenes (2pts)
    print_test "1.5. Red y volúmenes configurados"
    if docker compose config 2>/dev/null | grep -q "networks:" && \
       docker compose config 2>/dev/null | grep -q "volumes:"; then
        print_pass 2
        ((section_score+=2))
    else
        print_fail "Red o volúmenes no configurados"
    fi
    
    DOCKER_COMPOSE_POINTS=$section_score
    echo "" | tee -a "$OUTPUT_DIR/log.txt"
    echo -e "${BLUE}  Subtotal Sección 1: ${BOLD}$DOCKER_COMPOSE_POINTS / $DOCKER_COMPOSE_MAX puntos${NC}" | tee -a "$OUTPUT_DIR/log.txt"
}

# ============================================
# SECCIÓN 2: Contenedores (20 puntos)
# ============================================

validate_containers() {
    print_header "SECCIÓN 2: CONTENEDORES EN EJECUCIÓN (20 puntos)"
    local section_score=0
    
    ((TESTS_TOTAL+=4))
    
    print_info "Levantando servicios Docker..."
    if ! docker compose up -d > /dev/null 2>&1; then
        print_fail "Error al levantar servicios"
        CONTAINERS_POINTS=0
        return 1
    fi
    
    print_info "Esperando inicialización (60 segundos)..."
    sleep 60
    
    # Test 1-4: Cada contenedor (5pts c/u)
    print_test "2.1. Contenedor postgres-america corriendo"
    if docker compose ps | grep -q "postgres-america.*Up"; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Contenedor no está corriendo"
    fi
    
    print_test "2.2. Contenedor mysql-europe corriendo"
    if docker compose ps | grep -q "mysql-europe.*Up"; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Contenedor no está corriendo"
    fi
    
    print_test "2.3. Contenedor symmetricds-america corriendo"
    if docker compose ps | grep -q "symmetricds-america.*Up"; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Contenedor no está corriendo"
    fi
    
    print_test "2.4. Contenedor symmetricds-europe corriendo"
    if docker compose ps | grep -q "symmetricds-europe.*Up"; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Contenedor no está corriendo"
    fi
    
    CONTAINERS_POINTS=$section_score
    echo "" | tee -a "$OUTPUT_DIR/log.txt"
    echo -e "${BLUE}  Subtotal Sección 2: ${BOLD}$CONTAINERS_POINTS / $CONTAINERS_MAX puntos${NC}" | tee -a "$OUTPUT_DIR/log.txt"
}

# ============================================
# SECCIÓN 3: Bases de Datos (15 puntos)
# ============================================

validate_databases() {
    print_header "SECCIÓN 3: CONEXIÓN A BASES DE DATOS (15 puntos)"
    local section_score=0
    
    ((TESTS_TOTAL+=3))
    
    # Test 1: Conexión PostgreSQL (5pts)
    print_test "3.1. Conexión a PostgreSQL"
    if docker exec postgres-america psql -U symmetricds -d globalshop -c "SELECT 1;" > /dev/null 2>&1; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "No se puede conectar"
    fi
    
    # Test 2: Tablas en PostgreSQL (5pts)
    print_test "3.2. Tablas de negocio en PostgreSQL (4 tablas)"
    local pg_tables=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('products','inventory','customers','promotions');" 2>/dev/null | tr -d ' ')
    if [ "$pg_tables" = "4" ]; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Tablas faltantes ($pg_tables/4)"
    fi
    
    # Test 3: Conexión MySQL (5pts)
    print_test "3.3. Conexión a MySQL"
    if docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e "SELECT 1;" > /dev/null 2>&1; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "No se puede conectar"
    fi
    
    DATABASES_POINTS=$section_score
    echo "" | tee -a "$OUTPUT_DIR/log.txt"
    echo -e "${BLUE}  Subtotal Sección 3: ${BOLD}$DATABASES_POINTS / $DATABASES_MAX puntos${NC}" | tee -a "$OUTPUT_DIR/log.txt"
}

# ============================================
# SECCIÓN 4: SymmetricDS (15 puntos)
# ============================================

validate_symmetricds() {
    print_header "SECCIÓN 4: SYMMETRICDS CONFIGURACIÓN (15 puntos)"
    local section_score=0
    
    ((TESTS_TOTAL+=3))
    
    # Test 1: Tablas SymmetricDS en PostgreSQL (5pts)
    print_test "4.1. Tablas SymmetricDS en PostgreSQL (>30 tablas)"
    local sym_tables=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'sym_%';" 2>/dev/null | tr -d ' ')
    if [ "$sym_tables" -gt 30 ]; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Insuficientes ($sym_tables < 30)"
    fi
    
    # Test 2: Tablas SymmetricDS en MySQL (5pts)
    print_test "4.2. Tablas SymmetricDS en MySQL (>30 tablas)"
    local sym_tables_mysql=$(docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='globalshop' AND table_name LIKE 'sym_%';" 2>/dev/null)
    if [ "$sym_tables_mysql" -gt 30 ]; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Insuficientes ($sym_tables_mysql < 30)"
    fi
    
    # Test 3: Grupos de nodos configurados (5pts)
    print_test "4.3. Grupos de nodos configurados (≥2)"
    local node_groups=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM sym_node_group;" 2>/dev/null | tr -d ' ')
    if [ "$node_groups" -ge 2 ]; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "Grupos insuficientes ($node_groups < 2)"
    fi
    
    SYMMETRICDS_POINTS=$section_score
    echo "" | tee -a "$OUTPUT_DIR/log.txt"
    echo -e "${BLUE}  Subtotal Sección 4: ${BOLD}$SYMMETRICDS_POINTS / $SYMMETRICDS_MAX puntos${NC}" | tee -a "$OUTPUT_DIR/log.txt"
}

# ============================================
# SECCIÓN 5: Replicación (30 puntos)
# ============================================

validate_replication() {
    print_header "SECCIÓN 5: REPLICACIÓN BIDIRECCIONAL (30 puntos)"
    local section_score=0
    
    ((TESTS_TOTAL+=6))
    
    print_info "Esperando estabilización (15 segundos)..."
    sleep 15
    
    # Limpiar datos previos
    docker exec postgres-america psql -U symmetricds -d globalshop -c \
        "DELETE FROM products WHERE product_id IN ('TEST-CAL-PG', 'TEST-CAL-MY');" > /dev/null 2>&1
    docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e \
        "DELETE FROM products WHERE product_id IN ('TEST-CAL-PG', 'TEST-CAL-MY');" > /dev/null 2>&1
    sleep 5
    
    # Test 1: INSERT PostgreSQL → MySQL (10pts)
    print_test "5.1. INSERT: PostgreSQL → MySQL"
    docker exec postgres-america psql -U symmetricds -d globalshop -c \
        "INSERT INTO products (product_id, product_name, category, base_price, description, is_active) 
         VALUES ('TEST-CAL-PG', 'Test Replication PG', 'Test', 99.99, 'Test', true);" > /dev/null 2>&1
    
    sleep 15
    
    local count_mysql=$(docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -N -e \
        "SELECT COUNT(*) FROM products WHERE product_id = 'TEST-CAL-PG';" 2>/dev/null)
    
    if [ "$count_mysql" = "1" ]; then
        print_pass 10
        ((section_score+=10))
    else
        print_fail "No replicado (encontrados: $count_mysql)"
    fi
    
    # Test 2: INSERT MySQL → PostgreSQL (10pts)
    print_test "5.2. INSERT: MySQL → PostgreSQL"
    docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e \
        "INSERT INTO products (product_id, product_name, category, base_price, description, is_active) 
         VALUES ('TEST-CAL-MY', 'Test Replication MY', 'Test', 149.99, 'Test', 1);" > /dev/null 2>&1
    
    sleep 15
    
    local count_pg=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -A -c \
        "SELECT COUNT(*) FROM products WHERE product_id = 'TEST-CAL-MY';" 2>/dev/null)
    
    if [ "$count_pg" = "1" ]; then
        print_pass 10
        ((section_score+=10))
    else
        print_fail "No replicado (encontrados: $count_pg)"
    fi
    
    # Test 3: UPDATE PostgreSQL → MySQL (5pts)
    print_test "5.3. UPDATE: PostgreSQL → MySQL"
    docker exec postgres-america psql -U symmetricds -d globalshop -c \
        "UPDATE products SET base_price = 88.88 WHERE product_id = 'TEST-CAL-PG';" > /dev/null 2>&1
    
    sleep 15
    
    local price_mysql=$(docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -N -e \
        "SELECT base_price FROM products WHERE product_id = 'TEST-CAL-PG';" 2>/dev/null)
    
    if [ "$price_mysql" = "88.88" ]; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "No actualizado (precio: $price_mysql)"
    fi
    
    # Test 4: UPDATE MySQL → PostgreSQL (opcional, sin puntos pero contabiliza)
    print_test "5.4. UPDATE: MySQL → PostgreSQL"
    docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e \
        "UPDATE products SET base_price = 111.11 WHERE product_id = 'TEST-CAL-MY';" > /dev/null 2>&1
    
    sleep 15
    
    local price_pg=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -A -c \
        "SELECT base_price FROM products WHERE product_id = 'TEST-CAL-MY';" 2>/dev/null)
    
    if [ "$price_pg" = "111.11" ]; then
        echo -e "${GREEN}✓ (bonus)${NC}" | tee -a "$OUTPUT_DIR/log.txt"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}△ (opcional)${NC}" | tee -a "$OUTPUT_DIR/log.txt"
    fi
    
    # Test 5: DELETE PostgreSQL → MySQL (5pts)
    print_test "5.5. DELETE: PostgreSQL → MySQL"
    docker exec postgres-america psql -U symmetricds -d globalshop -c \
        "DELETE FROM products WHERE product_id = 'TEST-CAL-PG';" > /dev/null 2>&1
    
    sleep 15
    
    local del_mysql=$(docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -N -e \
        "SELECT COUNT(*) FROM products WHERE product_id = 'TEST-CAL-PG';" 2>/dev/null)
    
    if [ "$del_mysql" = "0" ]; then
        print_pass 5
        ((section_score+=5))
    else
        print_fail "No eliminado (encontrados: $del_mysql)"
    fi
    
    # Test 6: DELETE MySQL → PostgreSQL (opcional)
    print_test "5.6. DELETE: MySQL → PostgreSQL"
    docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e \
        "DELETE FROM products WHERE product_id = 'TEST-CAL-MY';" > /dev/null 2>&1
    
    sleep 15
    
    local del_pg=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -A -c \
        "SELECT COUNT(*) FROM products WHERE product_id = 'TEST-CAL-MY';" 2>/dev/null)
    
    if [ "$del_pg" = "0" ]; then
        echo -e "${GREEN}✓ (bonus)${NC}" | tee -a "$OUTPUT_DIR/log.txt"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}△ (opcional)${NC}" | tee -a "$OUTPUT_DIR/log.txt"
    fi
    
    REPLICATION_POINTS=$section_score
    echo "" | tee -a "$OUTPUT_DIR/log.txt"
    echo -e "${BLUE}  Subtotal Sección 5: ${BOLD}$REPLICATION_POINTS / $REPLICATION_MAX puntos${NC}" | tee -a "$OUTPUT_DIR/log.txt"
}

# ============================================
# Generar Reportes
# ============================================

generate_reports() {
    TOTAL_SCORE=$((DOCKER_COMPOSE_POINTS + CONTAINERS_POINTS + DATABASES_POINTS + SYMMETRICDS_POINTS + REPLICATION_POINTS))
    local percentage=$((TOTAL_SCORE * 100 / MAX_SCORE))
    
    # Determinar nota
    local nota=""
    local aprobado="false"
    if [ $percentage -ge 90 ]; then
        nota="A - Excelente"
        aprobado="true"
    elif [ $percentage -ge 80 ]; then
        nota="B - Bueno"
        aprobado="true"
    elif [ $percentage -ge 70 ]; then
        nota="C - Aceptable"
        aprobado="true"
    elif [ $percentage -ge 60 ]; then
        nota="D - Suficiente"
        aprobado="true"
    else
        nota="F - Insuficiente"
        aprobado="false"
    fi
    
    # ========== 1. JSON ==========
    cat > "$OUTPUT_DIR/calificaciones.json" << EOF
{
  "fecha": "$TIMESTAMP_ISO",
  "estudiantes": [
    {
      "nombre": "$STUDENT_NAME",
      "cedula": "$STUDENT_ID",
      "rama": "$BRANCH_NAME",
      "calificacion": {
        "total": $TOTAL_SCORE,
        "nota": "$nota",
        "aprobado": $aprobado
      },
      "desglose": {
        "docker_compose": { "obtenido": $DOCKER_COMPOSE_POINTS, "maximo": $DOCKER_COMPOSE_MAX },
        "contenedores": { "obtenido": $CONTAINERS_POINTS, "maximo": $CONTAINERS_MAX },
        "bases_datos": { "obtenido": $DATABASES_POINTS, "maximo": $DATABASES_MAX },
        "symmetricds": { "obtenido": $SYMMETRICDS_POINTS, "maximo": $SYMMETRICDS_MAX },
        "replicacion": { "obtenido": $REPLICATION_POINTS, "maximo": $REPLICATION_MAX }
      },
      "detalles": {
        "tests_pasados": $TESTS_PASSED,
        "tests_totales": $TESTS_TOTAL,
        "tablas_creadas": 4,
        "tablas_requeridas": 4,
        "servicios_docker": 4
      }
    }
  ],
  "estadisticas": {
    "total_estudiantes": 1,
    "aprobados": $([ "$aprobado" = "true" ] && echo 1 || echo 0),
    "reprobados": $([ "$aprobado" = "false" ] && echo 1 || echo 0),
    "promedio": $TOTAL_SCORE,
    "porcentaje_aprobados": $([ "$aprobado" = "true" ] && echo "100.00" || echo "0.00")
  }
}
EOF
    
    # ========== 2. CSV ==========
    cat > "$OUTPUT_DIR/calificaciones.csv" << EOF
nombre,cedula,rama,docker_compose,contenedores,bases_datos,symmetricds,replicacion,total,nota,aprobado
"$STUDENT_NAME",$STUDENT_ID,$BRANCH_NAME,$DOCKER_COMPOSE_POINTS,$CONTAINERS_POINTS,$DATABASES_POINTS,$SYMMETRICDS_POINTS,$REPLICATION_POINTS,$TOTAL_SCORE,"$nota",$aprobado
EOF
    
    # ========== 3. TXT (RESUMEN) ==========
    cat > "$OUTPUT_DIR/RESUMEN.txt" << EOF
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║      REPORTE DE CALIFICACIÓN AUTOMÁTICA - ABDD            ║
║      Replicación Bidireccional con SymmetricDS            ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

INFORMACIÓN DEL ESTUDIANTE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Nombre:    $STUDENT_NAME
  Cédula:    $STUDENT_ID
  Rama:      $BRANCH_NAME
  Fecha:     $(date)

CALIFICACIÓN FINAL:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TOTAL:     $TOTAL_SCORE / $MAX_SCORE puntos
  Nota:      $nota
  Estado:    $([ "$aprobado" = "true" ] && echo "APROBADO ✓" || echo "REPROBADO ✗")

DESGLOSE POR SECCIÓN:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Docker Compose           $DOCKER_COMPOSE_POINTS / $DOCKER_COMPOSE_MAX puntos
  2. Contenedores             $CONTAINERS_POINTS / $CONTAINERS_MAX puntos
  3. Bases de Datos           $DATABASES_POINTS / $DATABASES_MAX puntos
  4. SymmetricDS              $SYMMETRICDS_POINTS / $SYMMETRICDS_MAX puntos
  5. Replicación              $REPLICATION_POINTS / $REPLICATION_MAX puntos

ESTADÍSTICAS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Tests pasados:  $TESTS_PASSED / $TESTS_TOTAL
  Porcentaje:     ${percentage}%
  
EOF
    
    # ========== 4. LOG (detallado) ==========
    # Ya se generó en log.txt durante la ejecución
    mv "$OUTPUT_DIR/log.txt" "$OUTPUT_DIR/${STUDENT_NAME// /_}_${STUDENT_ID}.log" 2>/dev/null || true
    
    # Mostrar reporte en pantalla
    print_header "REPORTE FINAL DE CALIFICACIÓN"
    
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${BOLD}          DESGLOSE DE PUNTUACIÓN                    ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
    printf "${CYAN}│${NC} %-40s ${YELLOW}%4d${NC}/${GREEN}%4d${NC} ${CYAN}│${NC}\n" "1. Docker Compose" $DOCKER_COMPOSE_POINTS $DOCKER_COMPOSE_MAX
    printf "${CYAN}│${NC} %-40s ${YELLOW}%4d${NC}/${GREEN}%4d${NC} ${CYAN}│${NC}\n" "2. Contenedores" $CONTAINERS_POINTS $CONTAINERS_MAX
    printf "${CYAN}│${NC} %-40s ${YELLOW}%4d${NC}/${GREEN}%4d${NC} ${CYAN}│${NC}\n" "3. Bases de Datos" $DATABASES_POINTS $DATABASES_MAX
    printf "${CYAN}│${NC} %-40s ${YELLOW}%4d${NC}/${GREEN}%4d${NC} ${CYAN}│${NC}\n" "4. SymmetricDS" $SYMMETRICDS_POINTS $SYMMETRICDS_MAX
    printf "${CYAN}│${NC} %-40s ${YELLOW}%4d${NC}/${GREEN}%4d${NC} ${CYAN}│${NC}\n" "5. Replicación Bidireccional" $REPLICATION_POINTS $REPLICATION_MAX
    echo -e "${CYAN}├─────────────────────────────────────────────────────┤${NC}"
    printf "${CYAN}│${NC} ${BOLD}%-40s${NC} ${YELLOW}${BOLD}%4d${NC}/${GREEN}${BOLD}%4d${NC} ${CYAN}│${NC}\n" "CALIFICACIÓN FINAL" $TOTAL_SCORE $MAX_SCORE
    echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
    
    echo ""
    
    if [ $percentage -ge 90 ]; then
        echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${BOLD}   CALIFICACIÓN: EXCELENTE (A) - ${percentage}%              ${NC}${GREEN}║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    elif [ $percentage -ge 80 ]; then
        echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${BOLD}   CALIFICACIÓN: BUENO (B) - ${percentage}%                  ${NC}${GREEN}║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    elif [ $percentage -ge 70 ]; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${BOLD}   CALIFICACIÓN: ACEPTABLE (C) - ${percentage}%             ${NC}${YELLOW}║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════╝${NC}"
    elif [ $percentage -ge 60 ]; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${BOLD}   CALIFICACIÓN: SUFICIENTE (D) - ${percentage}%            ${NC}${YELLOW}║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${RED}╔═══════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${BOLD}   CALIFICACIÓN: INSUFICIENTE (F) - ${percentage}%          ${NC}${RED}║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════╝${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}📁 Reportes generados:${NC}"
    echo -e "   → ${CYAN}$OUTPUT_DIR/calificaciones.json${NC}"
    echo -e "   → ${CYAN}$OUTPUT_DIR/calificaciones.csv${NC}"
    echo -e "   → ${CYAN}$OUTPUT_DIR/RESUMEN.txt${NC}"
    echo -e "   → ${CYAN}$OUTPUT_DIR/${STUDENT_NAME// /_}_${STUDENT_ID}.log${NC}"
    echo ""
}

# ============================================
# Limpieza
# ============================================

cleanup() {
    print_header "LIMPIEZA"
    print_info "Deteniendo contenedores..."
    docker compose down -v > /dev/null 2>&1
    echo -e "${GREEN}✓ Ambiente limpio${NC}"
}

# ============================================
# Función Principal
# ============================================

main() {
    clear
    
    # Extraer info del estudiante
    extract_student_info
    
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║      SISTEMA DE CALIFICACIÓN AUTOMÁTICA - ABDD            ║"
    echo "║      Replicación Bidireccional con SymmetricDS            ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}Estudiante:${NC} ${BOLD}$STUDENT_NAME${NC}"
    echo -e "${BLUE}Cédula:${NC} $STUDENT_ID"
    echo -e "${BLUE}Rama:${NC} $BRANCH_NAME"
    echo ""
    echo -e "${YELLOW}Puntuación máxima: ${BOLD}100 puntos${NC}"
    echo ""
    
    # Crear archivo de log
    touch "$OUTPUT_DIR/log.txt"
    
    # Ejecutar validaciones
    validate_docker_compose || true
    validate_containers || true
    validate_databases || true
    validate_symmetricds || true
    validate_replication || true
    
    # Generar reportes
    generate_reports
    
    # Limpiar
    cleanup
    
    echo ""
    echo -e "${BLUE}Para ver el JSON:${NC} ${CYAN}cat $OUTPUT_DIR/calificaciones.json${NC}"
    echo ""
    
    # Retornar código según aprobación
    if [ $TOTAL_SCORE -ge 60 ]; then
        exit 0
    else
        exit 1
    fi
}

# Ejecutar
main
