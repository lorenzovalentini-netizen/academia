
DROP TABLE IF EXISTS itens_matricula CASCADE;
DROP TABLE IF EXISTS matriculas CASCADE;
DROP TABLE IF EXISTS modalidades CASCADE;
DROP TABLE IF EXISTS alunos CASCADE;
DROP TABLE IF EXISTS planos CASCADE;




CREATE TABLE alunos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    cpf CHAR(11) UNIQUE NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);




CREATE TABLE planos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) UNIQUE NOT NULL,
    valor_mensal_base DECIMAL(10,2) NOT NULL,
    
    CONSTRAINT chk_plano_valor
        CHECK (valor_mensal_base > 0)
);




CREATE TABLE modalidades (
    id SERIAL PRIMARY KEY,
    plano_id INTEGER NOT NULL,
    nome VARCHAR(100) NOT NULL,
    sala VARCHAR(50) NOT NULL,
    capacidade_maxima INTEGER NOT NULL,
    disponivel BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_modalidade_plano
        FOREIGN KEY (plano_id)
        REFERENCES planos(id),

    CONSTRAINT chk_capacidade
        CHECK (capacidade_maxima > 0)
);




CREATE TABLE matriculas (
    id SERIAL PRIMARY KEY,
    aluno_id INTEGER NOT NULL,
    data_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'Ativa',

    CONSTRAINT fk_matricula_aluno
        FOREIGN KEY (aluno_id)
        REFERENCES alunos(id),

    CONSTRAINT chk_status_matricula
        CHECK (status IN ('Ativa', 'Cancelada', 'Trancada'))
);




CREATE TABLE itens_matricula (
    id SERIAL PRIMARY KEY,
    matricula_id INTEGER NOT NULL,
    modalidade_id INTEGER NOT NULL,
    duracao_meses INTEGER NOT NULL,
    valor_mensal_aplicado DECIMAL(10,2) NOT NULL,
    taxa_adesao DECIMAL(10,2) DEFAULT 0.00,

    CONSTRAINT fk_item_matricula
        FOREIGN KEY (matricula_id)
        REFERENCES matriculas(id),

    CONSTRAINT fk_item_modalidade
        FOREIGN KEY (modalidade_id)
        REFERENCES modalidades(id),

    CONSTRAINT chk_duracao
        CHECK (duracao_meses > 0),

    CONSTRAINT chk_valor_mensal
        CHECK (valor_mensal_aplicado > 0),

    CONSTRAINT chk_taxa_adesao
        CHECK (taxa_adesao >= 0)
);




INSERT INTO planos (nome, valor_mensal_base)
VALUES
    ('VIP Premium', 180.00),
    ('Fitness Standard', 120.00),
    ('Basic Fit', 80.00);




INSERT INTO modalidades
    (plano_id, nome, sala, capacidade_maxima, disponivel)
VALUES
    (1, 'Crossfit Pro', 'Arena 01', 20, TRUE),
    (2, 'Pilates Avançado', 'Studio 02', 15, TRUE),
    (3, 'Musculação Livre', 'Sala 03', 30, TRUE);




INSERT INTO alunos
    (nome, email, cpf, telefone)
VALUES
    ('Lucas Almeida', 'lucas.almeida@email.com', '12345678901', '48999990001'),
    ('Mariana Souza', 'mariana.souza@email.com', '23456789012', '48999990002'),
    ('Gabriel Santos', 'gabriel.santos@email.com', '34567890123', '48999990003');




INSERT INTO matriculas
    (aluno_id, data_inicio, status)
VALUES
    (1, '2026-01-10 08:00:00', 'Ativa'),
    (1, '2026-02-15 09:00:00', 'Ativa'),
    (2, '2026-03-01 10:00:00', 'Ativa'),
    (3, '2026-01-20 14:00:00', 'Cancelada');




INSERT INTO itens_matricula
    (matricula_id, modalidade_id, duracao_meses, valor_mensal_aplicado, taxa_adesao)
VALUES
    (1, 1, 12, 180.00, 50.00),
    (2, 2, 6, 130.00, 30.00),
    (3, 1, 8, 180.00, 40.00),
    (4, 3, 4, 80.00, 0.00);




CREATE OR REPLACE VIEW vw_modalidades_custo_estimado AS
SELECT
    m.nome AS modalidade,
    m.sala,
    p.nome AS plano,
    ROUND(p.valor_mensal_base * 1.10, 2) AS valor_mensal_ajustado
FROM modalidades m
INNER JOIN planos p
    ON m.plano_id = p.id
ORDER BY valor_mensal_ajustado DESC;




CREATE OR REPLACE VIEW vw_matriculas_ativas AS
SELECT
    a.nome AS aluno,
    a.cpf,
    mo.nome AS modalidade,
    mo.sala,
    im.duracao_meses,
    mat.data_inicio
FROM matriculas mat
INNER JOIN alunos a
    ON mat.aluno_id = a.id
INNER JOIN itens_matricula im
    ON mat.id = im.matricula_id
INNER JOIN modalidades mo
    ON im.modalidade_id = mo.id
WHERE mat.status = 'Ativa';




CREATE OR REPLACE VIEW vw_alunos_vip AS
SELECT
    a.nome AS aluno,
    COUNT(DISTINCT mat.id) AS quantidade_contratos_ativos,
    ROUND(
        SUM(
            (im.valor_mensal_aplicado * im.duracao_meses)
            + im.taxa_adesao
        ),
        2
    ) AS valor_total_investido
FROM alunos a
INNER JOIN matriculas mat
    ON a.id = mat.aluno_id
INNER JOIN itens_matricula im
    ON mat.id = im.matricula_id
WHERE mat.status = 'Ativa'
GROUP BY a.id, a.nome
HAVING SUM(
    (im.valor_mensal_aplicado * im.duracao_meses)
    + im.taxa_adesao
) > 1000.00;




SELECT
    m.nome AS modalidade,
    m.sala,
    m.capacidade_maxima,
    p.nome AS plano,
    p.valor_mensal_base,
    m.disponivel
FROM modalidades m
INNER JOIN planos p
    ON m.plano_id = p.id
WHERE m.capacidade_maxima >= 15
  AND p.valor_mensal_base > 100.00
  AND m.disponivel = TRUE;




CREATE OR REPLACE VIEW vw_faturamento_medio_plano AS
SELECT
    p.nome AS plano,
    COALESCE(
        ROUND(
            SUM(
                (im.valor_mensal_aplicado * im.duracao_meses)
                + im.taxa_adesao
            ),
            2
        ),
        0.00
    ) AS faturamento_total_acumulado,

    COALESCE(
        ROUND(AVG(im.duracao_meses), 2),
        0.00
    ) AS media_duracao_contratos

FROM planos p
LEFT JOIN modalidades mo
    ON p.id = mo.plano_id
LEFT JOIN itens_matricula im
    ON mo.id = im.modalidade_id
LEFT JOIN matriculas mat
    ON im.matricula_id = mat.id
    AND mat.status = 'Ativa'

GROUP BY p.id, p.nome
ORDER BY p.nome;



SELECT * FROM vw_modalidades_custo_estimado;

SELECT * FROM vw_matriculas_ativas;

SELECT * FROM vw_alunos_vip;

SELECT * FROM vw_faturamento_medio_plano;