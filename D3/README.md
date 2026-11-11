# Salus Group Database Project - D3

## Authors

- Ana Paula Tavares - 68081
- Laura Silva - 68469
- Xiaoji Wu - 59800

aqui algumas dicas para executar o D3:

1. Atualizem primeiro o repositório:

git pull origin main

2. É necessário ter a base de dados D2 já criada e populada em PostgreSQL.

3. Abram Terminal dentro da pasta D3. Cada pessoa deve usar o seu próprio caminho.
Por exemplo:

cd ~/Downloads/IBD2627_D2_Goup11/D3

Ou podem arrastar a pasta D3 para o Terminal para obter o caminho correto.

4. Confirmem que o MongoDB está a correr:

mongosh --eval 'db.runCommand({ ping: 1 })'

Se devolver { ok: 1 }, podem continuar. Não é necessário voltar a iniciar o serviço.

5. Apenas na primeira vez:

chmod +x migration/migrate_from_postgres.sh

6. Indiquem o nome da vossa base de dados D2.
Exemplo:

export PGDATABASE=salus_d2_fulltest

Se a vossa base se chamar salus_d2, este passo não é necessário.

7. Executem a migração:

./migration/migrate_from_postgres.sh

No fim, os oito testes de consistência devem mostrar PASS.

8. Executem os data checks:

mongosh "mongodb://127.0.0.1:27017/salus_d3" \
  --file mongodb/02_data_checks.js

9. Executem as queries e CRUD:

mongosh "mongodb://127.0.0.1:27017/salus_d3" \
  --file mongodb/03_crud_and_queries.js

No fim deve aparecer:

Temporary document remaining: 0

10. Opcionalmente, podem confirmar outra vez a consistência:

export SYNC_FILE=generated/postgres_sync_counts.json

mongosh "mongodb://127.0.0.1:27017/salus_d3" \
  --file mongodb/04_consistency_checks.js