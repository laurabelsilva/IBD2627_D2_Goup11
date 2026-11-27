D4 - dados e scripts da fase de otimização (PostgreSQL e MongoDB).

Como instalar a base de dados salus_d4 de raiz
Requisitos: PostgreSQL 14 ou superior. Usar uma base de dados nova e vazia, porque o schema.sql apaga as tabelas existentes.

Executar os scripts por esta ordem, cada um uma só vez:

schema.sql – cria as tabelas, regras e triggers.
data_d4.sql – carrega os dados de teste (demora alguns minutos).
data_d4_ajustes.sql – ajusta sintomas, medicamentos e faturas.
ANALYZE; – atualiza as estatísticas do optimizer.

Com psql (terminal ou VS Code):
createdb salus_d4
psql -d salus_d4 -v ON_ERROR_STOP=1 -f schema.sql
psql -d salus_d4 -v ON_ERROR_STOP=1 -f data_d4.sql
psql -d salus_d4 -v ON_ERROR_STOP=1 -f data_d4_ajustes.sql
psql -d salus_d4 -c "ANALYZE;"

Com DBeaver: criar a base salus_d4, abrir cada ficheiro, confirmar que a ligação ativa é salus_d4 e executar como script (Alt + X).
Verificação: deve haver 38050 pessoas, 40002 compras, 38623 pagamentos e 39331 sintomas.

SELECT (SELECT COUNT(*) FROM person) AS pessoas,
       (SELECT COUNT(*) FROM purchase) AS compras,
       (SELECT COUNT(*) FROM payment) AS pagamentos,
       (SELECT COUNT(*) FROM symptom) AS sintomas;
Nota: o ficheiro dump-salus_d4-*.sql foi gerado com PostgreSQL 18 no Windows e pode não abrir em versões mais antigas. Usar os scripts acima.
