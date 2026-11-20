-- Script de creación de la base de datos del blog.
-- Compatible con MySQL 8 y MariaDB 10.6+.
-- Las fechas se almacenan en UTC.

-- Garantiza que los acentos y emojis se lean correctamente del script.
SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS bd_aplicacion_movil
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE bd_aplicacion_movil;

SET time_zone = '+00:00';

-- USUARIOS ---------------------------------------------------------------
-- tip_usu: 1 = administrador, 2 = usuario regular.
-- pass guarda el hash Argon2id, nunca la contraseña en texto plano.
CREATE TABLE usuario (
    id_usr INT AUTO_INCREMENT PRIMARY KEY,
    nom_usr VARCHAR(100) NOT NULL,
    mail VARCHAR(150) NOT NULL UNIQUE,
    pass VARCHAR(255) NOT NULL,
    dir_usr VARCHAR(200),
    tip_usu INT NOT NULL DEFAULT 2
);

-- BLOG -------------------------------------------------------------------
CREATE TABLE blog (
    id_blog INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    `desc` TEXT,
    img VARCHAR(500),
    tags VARCHAR(255),
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usr_id INT NOT NULL,

    INDEX idx_blog_usuario (usr_id),

    CONSTRAINT fk_blog_usuario
        FOREIGN KEY (usr_id)
        REFERENCES usuario(id_usr)
        ON DELETE CASCADE
);

-- estatus: 1 = visible, 0 = eliminado (borrado lógico).
CREATE TABLE comentarios (
    id_com INT AUTO_INCREMENT PRIMARY KEY,
    comentario TEXT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estatus INT NOT NULL DEFAULT 1,
    usr_id INT NOT NULL,
    blog_id INT NOT NULL,

    INDEX idx_comentario_blog (blog_id),

    CONSTRAINT fk_comentario_usuario
        FOREIGN KEY (usr_id)
        REFERENCES usuario(id_usr)
        ON DELETE CASCADE,

    CONSTRAINT fk_comentario_blog
        FOREIGN KEY (blog_id)
        REFERENCES blog(id_blog)
        ON DELETE CASCADE
);

-- Una calificación (1 a 5 estrellas) por usuario y publicación.
CREATE TABLE calificacion (
    id_cal INT AUTO_INCREMENT PRIMARY KEY,
    estrellas SMALLINT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    usr_id INT NOT NULL,
    blog_id INT NOT NULL,

    CONSTRAINT uq_calificacion_usuario_blog UNIQUE (usr_id, blog_id),
    CONSTRAINT ck_calificacion_estrellas CHECK (estrellas BETWEEN 1 AND 5),
    INDEX idx_calificacion_blog (blog_id),

    CONSTRAINT fk_calificacion_usuario
        FOREIGN KEY (usr_id)
        REFERENCES usuario(id_usr)
        ON DELETE CASCADE,

    CONSTRAINT fk_calificacion_blog
        FOREIGN KEY (blog_id)
        REFERENCES blog(id_blog)
        ON DELETE CASCADE
);

-- MENSAJERÍA -------------------------------------------------------------
-- Una conversación es un chat directo (2 miembros, sin nombre)
-- o un grupo (nombre obligatorio desde la API, N miembros).
CREATE TABLE conversacion (
    id_conv INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100),
    es_grupo BOOLEAN NOT NULL DEFAULT FALSE,
    creador_id INT,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_conversacion_creador
        FOREIGN KEY (creador_id)
        REFERENCES usuario(id_usr)
        ON DELETE SET NULL
);

CREATE TABLE conversacion_miembro (
    conv_id INT NOT NULL,
    usr_id INT NOT NULL,
    fecha_union DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Último mensaje leído; permite calcular los no leídos.
    ultimo_leido_id INT NOT NULL DEFAULT 0,

    PRIMARY KEY (conv_id, usr_id),
    INDEX idx_miembro_usuario (usr_id),

    CONSTRAINT fk_miembro_conversacion
        FOREIGN KEY (conv_id)
        REFERENCES conversacion(id_conv)
        ON DELETE CASCADE,

    CONSTRAINT fk_miembro_usuario
        FOREIGN KEY (usr_id)
        REFERENCES usuario(id_usr)
        ON DELETE CASCADE
);

CREATE TABLE mensaje (
    id_msg INT AUTO_INCREMENT PRIMARY KEY,
    contenido TEXT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    conv_id INT NOT NULL,
    usr_id INT NOT NULL,

    INDEX idx_mensaje_conversacion (conv_id, id_msg),

    CONSTRAINT fk_mensaje_conversacion
        FOREIGN KEY (conv_id)
        REFERENCES conversacion(id_conv)
        ON DELETE CASCADE,

    CONSTRAINT fk_mensaje_usuario
        FOREIGN KEY (usr_id)
        REFERENCES usuario(id_usr)
        ON DELETE CASCADE
);

-- DATOS DE PRUEBA --------------------------------------------------------
-- Contraseñas:
--   admin@ejemplo.com    -> Admin123!
--   adriana@ejemplo.com  -> Usuario123!
--   carlos@ejemplo.com   -> Usuario123!
INSERT INTO usuario
    (nom_usr, mail, pass, dir_usr, tip_usu)
VALUES
    ('Administrador', 'admin@ejemplo.com',
     '$argon2id$v=19$m=65536,t=3,p=4$9bjmyTCBCqb4v0CaLLA5IQ$sMK/x6+GEaqvdn9dFx6Wt7sAuRp0jHcKmb8vjCe8fgM',
     'Querétaro', 1),
    ('Adriana Contreras', 'adriana@ejemplo.com',
     '$argon2id$v=19$m=65536,t=3,p=4$2DxKPnMTTCTHTGxyK3pL4w$uilUgq9ASeZ/WV1mX2p7r5/TfQVcVb9uqudyqf64i88',
     'Querétaro', 2),
    ('Carlos Pérez', 'carlos@ejemplo.com',
     '$argon2id$v=19$m=65536,t=3,p=4$2DxKPnMTTCTHTGxyK3pL4w$uilUgq9ASeZ/WV1mX2p7r5/TfQVcVb9uqudyqf64i88',
     'Querétaro', 2);

INSERT INTO blog (titulo, `desc`, img, tags, usr_id)
VALUES
    (
      'Construyendo aplicaciones con Flutter',
      'Una introducción al desarrollo móvil con Dart.',
      'https://picsum.photos/800/400?random=1',
      'Flutter,Dart',
      2
    ),
    (
      'Introducción a la inteligencia artificial',
      'Conceptos fundamentales de inteligencia artificial.',
      'https://picsum.photos/800/400?random=2',
      'IA,tecnología',
      3
    );

INSERT INTO comentarios
    (comentario, estatus, usr_id, blog_id)
VALUES
    ('Muy útil la explicación de Flutter.', 1, 3, 1),
    ('Me gustaría ver más ejemplos.', 1, 1, 1),
    ('Buen artículo de introducción.', 1, 2, 2);

INSERT INTO calificacion (estrellas, usr_id, blog_id)
VALUES
    (5, 3, 1),
    (4, 1, 1),
    (4, 2, 2);

INSERT INTO conversacion (nombre, es_grupo, creador_id)
VALUES
    (NULL, FALSE, 2),
    ('Equipo del blog', TRUE, 1);

INSERT INTO conversacion_miembro (conv_id, usr_id, ultimo_leido_id)
VALUES
    (1, 2, 1), (1, 3, 2),
    (2, 1, 3), (2, 2, 0), (2, 3, 0);

INSERT INTO mensaje (contenido, conv_id, usr_id)
VALUES
    ('¡Hola Carlos! ¿Viste mi nueva publicación?', 1, 2),
    ('¡Sí! Me encantó, ya le puse 5 estrellas.', 1, 3),
    ('Bienvenidos al grupo del blog 👋', 2, 1);
