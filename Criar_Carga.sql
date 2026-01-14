CREATE TABLE usuarios (
  id SERIAL PRIMARY KEY,
  nome TEXT,
  email TEXT,
  criado_em TIMESTAMP DEFAULT now()
);
INSERT INTO usuarios (nome, email) SELECT 'Usuario ' || generate_series, 'email' || generate_series || '@teste.com' FROM generate_series(1, 100000);


