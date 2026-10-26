-- =====================================================================
-- BACKDOOR OVERRIDE - Esquema PostgreSQL v2 (demo dias 1-5)
-- Uso: psql -U postgres -c "CREATE DATABASE backdoor;"
--      psql -U postgres -d backdoor_override -f backdoor_override_schema.sql
-- =====================================================================

DROP SCHEMA IF EXISTS juego CASCADE;
CREATE SCHEMA juego;
SET search_path TO juego;

-- ---------- Tipos enumerados ----------
CREATE TYPE variable_juego  AS ENUM ('creditos','sospecha','confianza_nadia','indicios');
CREATE TYPE tipo_escena     AS ENUM ('narrativa','tutorial','inspeccion','decision','cierre','final');
CREATE TYPE resultado_op    AS ENUM ('aprobado','rechazado','falsificado','ignorado');
CREATE TYPE tipo_anomalia   AS ENUM ('destino_discrepante','vigilancia','regla_normativa','manipulacion');
CREATE TYPE tipo_personaje  AS ENUM ('protagonista','aliado','antagonista_institucional','sistema','secundario','cliente');

-- ---------- Catalogo de contenido (estatico) ----------
CREATE TABLE personaje (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL UNIQUE,
    rol         VARCHAR(120) NOT NULL,
    tipo        tipo_personaje NOT NULL,
    descripcion TEXT
);

CREATE TABLE jornada (
    id                   SERIAL PRIMARY KEY,
    numero               SMALLINT NOT NULL UNIQUE CHECK (numero BETWEEN 1 AND 5),
    titulo               VARCHAR(120) NOT NULL,
    objetivo_narrativo   TEXT NOT NULL,
    objetivo_jugable     TEXT NOT NULL,
    deuda_diaria         INTEGER NOT NULL DEFAULT 0 CHECK (deuda_diaria >= 0)
);

CREATE TABLE escena (
    id          SERIAL PRIMARY KEY,
    jornada_id  INTEGER NOT NULL REFERENCES jornada(id) ON DELETE CASCADE,
    orden       SMALLINT NOT NULL,
    titulo      VARCHAR(120) NOT NULL,
    tipo        tipo_escena NOT NULL,
    UNIQUE (jornada_id, orden)
);

-- Condicion simple para variantes de dialogo, p. ej. "sospecha<20" o "confianza_nadia>=1"
CREATE TABLE linea_dialogo (
    id           SERIAL PRIMARY KEY,
    escena_id    INTEGER NOT NULL REFERENCES escena(id) ON DELETE CASCADE,
    orden        SMALLINT NOT NULL,
    personaje_id INTEGER REFERENCES personaje(id),   -- NULL = narrador / pensamiento
    texto        TEXT NOT NULL,
    variable_cond variable_juego,
    operador_cond VARCHAR(2) CHECK (operador_cond IN ('<','<=','=','>=','>')),
    valor_cond    INTEGER,
    UNIQUE (escena_id, orden),
    CHECK ( (variable_cond IS NULL) = (operador_cond IS NULL)
        AND (operador_cond IS NULL) = (valor_cond IS NULL) )
);

CREATE TABLE regla (
    id             SERIAL PRIMARY KEY,
    codigo         VARCHAR(40) NOT NULL UNIQUE,
    descripcion    TEXT NOT NULL,
    dia_activacion SMALLINT NOT NULL CHECK (dia_activacion BETWEEN 1 AND 5),
    dia_fin        SMALLINT CHECK (dia_fin BETWEEN 1 AND 5),   -- NULL = vigente hasta el final de la demo
    campo_afectado VARCHAR(40),     -- 'sector', 'ultimo_digito', 'destino'...
    valor_afectado VARCHAR(40),     -- 'Este', 'impar'...
    es_arbitraria  BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (dia_fin IS NULL OR dia_fin >= dia_activacion)
);

CREATE TABLE decision (
    id          SERIAL PRIMARY KEY,
    escena_id   INTEGER NOT NULL REFERENCES escena(id) ON DELETE CASCADE,
    codigo      VARCHAR(40) NOT NULL UNIQUE,
    enunciado   TEXT NOT NULL
);

CREATE TABLE opcion (
    id          SERIAL PRIMARY KEY,
    decision_id INTEGER NOT NULL REFERENCES decision(id) ON DELETE CASCADE,
    etiqueta    VARCHAR(80) NOT NULL,
    descripcion TEXT,
    tiene_riesgo BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (decision_id, etiqueta),
    UNIQUE (decision_id, id)          -- necesario para la FK compuesta de partida_decision
);

-- efecto_opcion DEFINE la consecuencia posible. efecto_pendiente la PROGRAMA para una partida.
-- historial_variable registra lo que se HA aplicado realmente.
-- dia_offset: 0 = inmediato, 1 = al inicio del dia siguiente...
-- probabilidad: 1.0 = siempre; <1 permite la deteccion probabilistica del dia 4
CREATE TABLE efecto_opcion (
    id            SERIAL PRIMARY KEY,
    opcion_id     INTEGER NOT NULL REFERENCES opcion(id) ON DELETE CASCADE,
    variable      variable_juego NOT NULL,
    delta         INTEGER NOT NULL,
    dia_offset    SMALLINT NOT NULL DEFAULT 0 CHECK (dia_offset >= 0),
    probabilidad  NUMERIC(3,2) NOT NULL DEFAULT 1.00 CHECK (probabilidad > 0 AND probabilidad <= 1)
);

CREATE TABLE indicio (
    id          SERIAL PRIMARY KEY,
    codigo      VARCHAR(40) NOT NULL UNIQUE,
    titulo      VARCHAR(120) NOT NULL,
    descripcion TEXT NOT NULL,
    dia_origen  SMALLINT CHECK (dia_origen BETWEEN 1 AND 5)
);

-- ---------- Estado persistente de la partida ----------
CREATE TABLE partida (
    id               SERIAL PRIMARY KEY,
    nombre_jugador   VARCHAR(60) NOT NULL DEFAULT 'Operador',
    dia_actual       SMALLINT NOT NULL DEFAULT 1 CHECK (dia_actual BETWEEN 1 AND 5),
    creditos         INTEGER NOT NULL DEFAULT 0,
    sospecha         INTEGER NOT NULL DEFAULT 0 CHECK (sospecha >= 0),
    confianza_nadia  INTEGER NOT NULL DEFAULT 0,
    indicios         INTEGER NOT NULL DEFAULT 0 CHECK (indicios >= 0),
    desahuciado      BOOLEAN NOT NULL DEFAULT FALSE,
    finalizada       BOOLEAN NOT NULL DEFAULT FALSE,
    creada_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizada_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Opciones elegidas por el jugador. La FK compuesta impide registrar una opcion
-- que no pertenezca a la decision indicada; UNIQUE = una sola eleccion por decision y partida.
CREATE TABLE partida_decision (
    id          SERIAL PRIMARY KEY,
    partida_id  INTEGER NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    decision_id INTEGER NOT NULL REFERENCES decision(id),
    opcion_id   INTEGER NOT NULL,
    dia         SMALLINT NOT NULL,
    tomada_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (partida_id, decision_id),
    FOREIGN KEY (decision_id, opcion_id) REFERENCES opcion(decision_id, id)
);

-- Efectos programados para dias posteriores (p. ej. Sospecha +15 al inicio del dia 4).
-- UNIQUE (partida_id, efecto_opcion_id) evita programar dos veces la misma consecuencia;
-- CHECK garantiza que 'aplicado' y 'aplicado_en' siempre sean coherentes.
CREATE TABLE efecto_pendiente (
    id               SERIAL PRIMARY KEY,
    partida_id       INTEGER NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    efecto_opcion_id INTEGER NOT NULL REFERENCES efecto_opcion(id),
    variable         variable_juego NOT NULL,
    delta            INTEGER NOT NULL,
    dia_aplicar      SMALLINT NOT NULL,
    aplicado         BOOLEAN NOT NULL DEFAULT FALSE,
    aplicado_en      TIMESTAMPTZ,
    UNIQUE (partida_id, efecto_opcion_id),
    CHECK (aplicado = (aplicado_en IS NOT NULL))
);

CREATE TABLE partida_indicio (
    partida_id  INTEGER NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    indicio_id  INTEGER NOT NULL REFERENCES indicio(id),
    obtenido_dia SMALLINT NOT NULL,
    PRIMARY KEY (partida_id, indicio_id)
);

-- Registro de operaciones: INSTANTANEA del tramite en el momento de realizarlo.
-- Cliente, documento y billete son objetos transitorios del juego; se copian aqui
-- los datos relevantes para que el historial no cambie si cambia el contenido.
CREATE TABLE registro_operacion (
    id                SERIAL PRIMARY KEY,
    partida_id        INTEGER NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    dia               SMALLINT NOT NULL,
    cliente_nombre    VARCHAR(80) NOT NULL,
    destino_declarado VARCHAR(80),
    codigo_temporal   VARCHAR(40),
    ultimo_digito     SMALLINT CHECK (ultimo_digito BETWEEN 0 AND 9),
    sector_residencia VARCHAR(20),
    resultado         resultado_op NOT NULL,
    regla_id          INTEGER REFERENCES regla(id),
    creditos_delta    INTEGER NOT NULL DEFAULT 0,
    sospecha_delta    INTEGER NOT NULL DEFAULT 0,
    registrada_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Anomalias detectadas en una operacion (cero o varias por registro)
CREATE TABLE anomalia (
    id                    SERIAL PRIMARY KEY,
    registro_operacion_id INTEGER NOT NULL REFERENCES registro_operacion(id) ON DELETE CASCADE,
    tipo                  tipo_anomalia NOT NULL,
    detalle               TEXT
);

-- Historial de cambios en variables (auditoria para pruebas y balance)
CREATE TABLE historial_variable (
    id          BIGSERIAL PRIMARY KEY,
    partida_id  INTEGER NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    variable    variable_juego NOT NULL,
    valor_antes INTEGER NOT NULL,
    valor_despues INTEGER NOT NULL,
    motivo      VARCHAR(160),
    dia         SMALLINT NOT NULL,
    cambiado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_escena_jornada      ON escena(jornada_id, orden);
CREATE INDEX idx_dialogo_escena      ON linea_dialogo(escena_id, orden);
CREATE INDEX idx_registro_partida    ON registro_operacion(partida_id, dia);
CREATE INDEX idx_historial_partida   ON historial_variable(partida_id, variable);
CREATE INDEX idx_anomalia_registro    ON anomalia(registro_operacion_id);
CREATE INDEX idx_pendiente_partida   ON efecto_pendiente(partida_id, dia_aplicar) WHERE NOT aplicado;

-- =====================================================================
-- FUNCIONES DE LOGICA DE JUEGO
-- =====================================================================

-- Rango de sospecha segun el documento de diseno
CREATE OR REPLACE FUNCTION rango_sospecha(p_valor INTEGER) RETURNS TEXT AS $$
    SELECT CASE
        WHEN p_valor >= 40 THEN 'intervencion_agresiva'
        WHEN p_valor >= 20 THEN 'controles_adicionales'
        ELSE 'vigilancia_discreta'
    END;
$$ LANGUAGE sql IMMUTABLE;

-- UNICA VIA para modificar creditos/sospecha/confianza_nadia/indicios:
-- este trigger rechaza cualquier UPDATE directo que no pase por aplicar_efecto().
CREATE OR REPLACE FUNCTION proteger_variables() RETURNS trigger AS $$
BEGIN
    IF (NEW.creditos, NEW.sospecha, NEW.confianza_nadia, NEW.indicios)
       IS DISTINCT FROM (OLD.creditos, OLD.sospecha, OLD.confianza_nadia, OLD.indicios)
       AND coalesce(current_setting('juego.via_funcion', true), 'off') <> 'on' THEN
        RAISE EXCEPTION 'Las variables de la partida solo pueden modificarse con aplicar_efecto()';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_proteger_variables BEFORE UPDATE ON partida
FOR EACH ROW EXECUTE FUNCTION proteger_variables();

-- Aplica un cambio a una variable, lo registra en el historial y comprueba el desahucio
CREATE OR REPLACE FUNCTION aplicar_efecto(
    p_partida INTEGER, p_variable variable_juego, p_delta INTEGER, p_motivo TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_antes   INTEGER;
    v_despues INTEGER;
    v_dia     SMALLINT;
BEGIN
    SELECT dia_actual,
           CASE p_variable
                WHEN 'creditos'        THEN creditos
                WHEN 'sospecha'        THEN sospecha
                WHEN 'confianza_nadia' THEN confianza_nadia
                WHEN 'indicios'        THEN indicios
           END
      INTO v_dia, v_antes
      FROM partida WHERE id = p_partida FOR UPDATE;

    v_despues := v_antes + p_delta;
    IF p_variable IN ('sospecha','indicios') THEN
        v_despues := GREATEST(v_despues, 0);
    END IF;

    PERFORM set_config('juego.via_funcion', 'on', true);   -- valido solo en esta transaccion
    UPDATE partida SET
        creditos        = CASE WHEN p_variable = 'creditos'        THEN v_despues ELSE creditos END,
        sospecha        = CASE WHEN p_variable = 'sospecha'        THEN v_despues ELSE sospecha END,
        confianza_nadia = CASE WHEN p_variable = 'confianza_nadia' THEN v_despues ELSE confianza_nadia END,
        indicios        = CASE WHEN p_variable = 'indicios'        THEN v_despues ELSE indicios END,
        actualizada_en  = now()
    WHERE id = p_partida;

    PERFORM set_config('juego.via_funcion', 'off', true);

    INSERT INTO historial_variable(partida_id, variable, valor_antes, valor_despues, motivo, dia)
    VALUES (p_partida, p_variable, v_antes, v_despues, p_motivo, v_dia);
END;
$$ LANGUAGE plpgsql;

-- Aplica todos los efectos de una opcion y guarda la decision (todo en una transaccion).
-- Los efectos con dia_offset > 0 se programan como efecto_pendiente (sin duplicados).
CREATE OR REPLACE FUNCTION elegir_opcion(p_partida INTEGER, p_opcion INTEGER) RETURNS VOID AS $$
DECLARE
    e     RECORD;
    v_dia SMALLINT;
    v_dec INTEGER;
BEGIN
    SELECT dia_actual INTO v_dia FROM partida WHERE id = p_partida FOR UPDATE;
    SELECT decision_id INTO v_dec FROM opcion WHERE id = p_opcion;
    IF v_dec IS NULL THEN RAISE EXCEPTION 'Opcion % inexistente', p_opcion; END IF;

    -- la restriccion UNIQUE(partida_id, decision_id) impide elegir dos veces
    INSERT INTO partida_decision(partida_id, decision_id, opcion_id, dia)
    VALUES (p_partida, v_dec, p_opcion, v_dia);

    FOR e IN SELECT * FROM efecto_opcion WHERE opcion_id = p_opcion LOOP
        IF e.probabilidad < 1 AND random() > e.probabilidad THEN
            CONTINUE;   -- el efecto probabilistico no se activa esta vez
        END IF;
        IF e.dia_offset = 0 THEN
            PERFORM aplicar_efecto(p_partida, e.variable, e.delta, 'opcion ' || p_opcion);
        ELSE
            INSERT INTO efecto_pendiente(partida_id, efecto_opcion_id, variable, delta, dia_aplicar)
            VALUES (p_partida, e.id, e.variable, e.delta, v_dia + e.dia_offset)
            ON CONFLICT (partida_id, efecto_opcion_id) DO NOTHING;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Inicio de jornada: aplica efectos pendientes del dia
CREATE OR REPLACE FUNCTION iniciar_jornada(p_partida INTEGER, p_dia SMALLINT) RETURNS VOID AS $$
DECLARE
    e RECORD;
BEGIN
    UPDATE partida SET dia_actual = p_dia, actualizada_en = now() WHERE id = p_partida;
    -- FOR UPDATE bloquea las filas: un efecto pendiente no puede aplicarse dos veces
    FOR e IN SELECT * FROM efecto_pendiente
              WHERE partida_id = p_partida AND dia_aplicar = p_dia AND NOT aplicado
              ORDER BY id FOR UPDATE LOOP
        PERFORM aplicar_efecto(p_partida, e.variable, e.delta, 'efecto diferido');
        UPDATE efecto_pendiente SET aplicado = TRUE, aplicado_en = now() WHERE id = e.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Cierre de jornada: cobra la deuda diaria y comprueba desahucio (saldo <= -50)
CREATE OR REPLACE FUNCTION cerrar_jornada(p_partida INTEGER) RETURNS BOOLEAN AS $$
DECLARE
    v_dia     SMALLINT;
    v_deuda   INTEGER;
    v_saldo   INTEGER;
BEGIN
    SELECT dia_actual INTO v_dia FROM partida WHERE id = p_partida;
    SELECT deuda_diaria INTO v_deuda FROM jornada WHERE numero = v_dia;

    PERFORM aplicar_efecto(p_partida, 'creditos', -v_deuda, 'deuda diaria');
    SELECT creditos INTO v_saldo FROM partida WHERE id = p_partida;

    IF v_saldo <= -50 THEN
        UPDATE partida SET desahuciado = TRUE, finalizada = TRUE WHERE id = p_partida;
        RETURN TRUE;   -- game over
    END IF;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Variante del dialogo final de Vance segun sospecha acumulada
CREATE OR REPLACE VIEW v_ruta_vance AS
SELECT id AS partida_id, sospecha, rango_sospecha(sospecha) AS rango,
       CASE WHEN sospecha >= 20 THEN 'ruta_sospecha_alta' ELSE 'ruta_sospecha_baja' END AS ruta
FROM partida;

-- =====================================================================
-- DATOS SEMILLA DE LA DEMO
-- =====================================================================

INSERT INTO personaje(nombre, rol, tipo, descripcion) VALUES
 ('Operador',        'El operador de la terminal',   'protagonista', 'Persona endeudada que intenta evitar el desahucio.'),
 ('Nadia Volkov',    'La activista de La Flecha',    'aliado',       'Busca a su hermano pintor desaparecido.'),
 ('Marcus Glitches', 'El intermediario',             'aliado',       'Contacto con el mercado negro.'),
 ('Inspector Vance', 'La amenaza institucional',     'antagonista_institucional', 'Ministerio de Seguridad.'),
 ('Asistente Virtual','Interfaz del sistema clandestino','sistema',  'Software pirateado con instrucciones contradictorias.'),
 ('Sir Reginald',    'Cliente adinerado reincidente','secundario',   'Usa los viajes como entretenimiento.'),
 ('Aris',            'Defensor del Parlamento Algoritmico','secundario','Recuerda la gran crisis de 2180.'),
 ('Familia del estudiante','Coste humano de las restricciones','secundario','Madre y estudiante.');

INSERT INTO jornada(numero, titulo, objetivo_narrativo, objetivo_jugable, deuda_diaria) VALUES
 (1,'El contrato del desesperado','Presentar mundo, protagonista y negocio clandestino.','Aprender a validar documentos y detectar discrepancias.',10),
 (2,'El cliente reincidente y la fachada del orden','Mostrar la defensa ideologica del sistema.','Introducir restricciones geopoliticas.',10),
 (3,'El primer cabo suelto','Introducir a Nadia y su motivacion.','Decision entre seguridad y confianza.',10),
 (4,'La anomalia sistemica','Convertir la critica al sistema en contradiccion verificable.','Tres opciones con costes distintos.',10),
 (5,'La redada inevitable','Confirmar que las autoridades conocen las terminales.','Reflejar decisiones acumuladas en el entorno y el dialogo de Vance.',10);

INSERT INTO escena(jornada_id, orden, titulo, tipo) VALUES
 (1,1,'La deuda','narrativa'),
 (1,2,'El tutorial','tutorial'),
 (1,3,'El primer cliente','inspeccion'),
 (1,4,'Sir Reginald','decision'),
 (1,5,'Cierre de jornada','cierre'),
 (2,1,'El regreso de Sir Reginald','inspeccion'),
 (2,2,'Aris y la confianza en las maquinas','narrativa'),
 (2,3,'La nueva restriccion','inspeccion'),
 (2,4,'Cierre de jornada','cierre'),
 (3,1,'Una solicitud sospechosa','inspeccion'),
 (3,2,'La motivacion de Nadia','narrativa'),
 (3,3,'La decision','decision'),
 (3,4,'La consecuencia','cierre'),
 (4,1,'Una orden absurda','narrativa'),
 (4,2,'El estudiante','inspeccion'),
 (4,3,'Las tres decisiones','decision'),
 (4,4,'La primera prueba','cierre'),
 (5,1,'El sotano cambia','narrativa'),
 (5,2,'El regreso de Nadia','narrativa'),
 (5,3,'La interrupcion','narrativa'),
 (5,4,'Vance y las consecuencias','narrativa'),
 (5,5,'Final de la demo','final');

INSERT INTO regla(codigo, descripcion, dia_activacion, campo_afectado, valor_afectado, es_arbitraria) VALUES
 ('DESTINO_COINCIDE','El destino declarado debe coincidir con el codigo temporal.',1,'destino',NULL,FALSE),
 ('RESTRICCION_SECTOR_ESTE','Denegar billetes a residentes del Sector Este.',2,'sector','Este',FALSE),
 ('DIGITO_IMPAR','Rechazar billetes encriptados cuyo ultimo digito sea impar.',4,'ultimo_digito','impar',TRUE);

-- Decisiones del dia 1 (Sir Reginald), dia 3 (Nadia) y dia 4 (estudiante)
INSERT INTO decision(escena_id, codigo, enunciado)
SELECT e.id, d.codigo, d.enunciado FROM (VALUES
 (1,4,'D1_ENCENDEDOR','Aceptar el encendedor de oro de Sir Reginald?'),
 (3,3,'D3_NADIA','Permitir o rechazar el viaje de Nadia a Viena 1900?'),
 (4,3,'D4_ESTUDIANTE','Que hacer con el billete del estudiante (digito impar)?')
) AS d(jornada, orden, codigo, enunciado)
JOIN escena e ON e.orden = d.orden AND e.jornada_id = (SELECT id FROM jornada WHERE numero = d.jornada);

INSERT INTO opcion(decision_id, etiqueta, descripcion, tiene_riesgo)
SELECT d.id, o.etiqueta, o.descripcion, o.riesgo FROM (VALUES
 ('D1_ENCENDEDOR','Aceptar','Cobrar el soborno.',TRUE),
 ('D1_ENCENDEDOR','Rechazar','No modificar variables.',FALSE),
 ('D3_NADIA','Dejar pasar','Confianza +1; alerta de seguridad al dia siguiente.',TRUE),
 ('D3_NADIA','Rechazar','Nadia deja la carta de su hermano.',FALSE),
 ('D4_ESTUDIANTE','Obedecer','La familia pierde el deposito.',FALSE),
 ('D4_ESTUDIANTE','Desobedecer','Infraccion deliberada registrada.',TRUE),
 ('D4_ESTUDIANTE','Falsificar el registro','Parche de software; posible deteccion.',TRUE)
) AS o(dec, etiqueta, descripcion, riesgo)
JOIN decision d ON d.codigo = o.dec;

INSERT INTO efecto_opcion(opcion_id, variable, delta, dia_offset, probabilidad)
SELECT op.id, f.variable::variable_juego, f.delta, f.offs, f.prob FROM (VALUES
 ('D1_ENCENDEDOR','Aceptar','creditos',20,0,1.00),
 ('D1_ENCENDEDOR','Aceptar','sospecha',5,0,1.00),
 ('D3_NADIA','Dejar pasar','confianza_nadia',1,0,1.00),
 ('D3_NADIA','Dejar pasar','sospecha',15,1,1.00),     -- al inicio del dia 4
 ('D3_NADIA','Rechazar','indicios',1,0,1.00),
 ('D4_ESTUDIANTE','Desobedecer','sospecha',20,0,1.00),
 ('D4_ESTUDIANTE','Falsificar el registro','creditos',-15,0,1.00),
 ('D4_ESTUDIANTE','Falsificar el registro','sospecha',10,0,0.40)  -- probabilidad ajustable en balance
) AS f(dec, etiqueta, variable, delta, offs, prob)
JOIN decision d ON d.codigo = f.dec
JOIN opcion op ON op.decision_id = d.id AND op.etiqueta = f.etiqueta;

INSERT INTO indicio(codigo, titulo, descripcion, dia_origen) VALUES
 ('CARTA_HERMANO','Carta del hermano de Nadia','Menciona agentes del Gobierno cerca de las terminales antes de su viaje.',3),
 ('LISTA_TERMINALES','Lista de terminales clandestinas','Orden de operaciones: mantener operativos los sectores 7 y 9.',5);

-- Dialogos condicionales de Vance (dia 5, escena 4)
INSERT INTO linea_dialogo(escena_id, orden, personaje_id, texto, variable_cond, operador_cond, valor_cond)
SELECT e.id, v.orden, p.id, v.texto, v.var::variable_juego, v.op, v.val FROM (VALUES
 (1,'Haces un buen trabajo manteniendo el orden aqui abajo, muchacho.','sospecha','<',20),
 (2,'Te creias muy listo jugando a ser el salvador, verdad?','sospecha','>=',20)
) AS v(orden, texto, var, op, val)
JOIN personaje p ON p.nombre = 'Inspector Vance'
JOIN escena e ON e.orden = 4 AND e.jornada_id = (SELECT id FROM jornada WHERE numero = 5);

-- Partida de ejemplo para pruebas
--INSERT INTO partida(nombre_jugador) VALUES ('Jugador de prueba');

-- Ejemplo de flujo:
--   SELECT elegir_opcion(1, (SELECT id FROM opcion WHERE etiqueta='Aceptar'));
--   SELECT cerrar_jornada(1);
--   SELECT iniciar_jornada(1, 2::smallint);
--   SELECT * FROM v_ruta_vance;