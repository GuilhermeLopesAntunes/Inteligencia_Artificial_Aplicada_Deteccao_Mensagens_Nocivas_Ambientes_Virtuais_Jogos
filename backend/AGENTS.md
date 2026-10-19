# Backend (FastAPI)

API de inferência, regras de negócio, persistência e WebSocket. Leia também `../.agents/regras-de-negocio.md` e `../.agents/contrato-api.md` antes de implementar qualquer rota ou regra.

## Estrutura e dependências entre camadas

```
src/
├── main.py              # Cria o app, CORS, routers, lifespan (scheduler)
├── seed.py              # Dados de demonstração (python -m src.seed)
├── config.py            # Settings via variáveis de ambiente (pydantic-settings)
├── api/                 # Rotas, schemas Pydantic de request/response, WebSocket
├── services/            # Casos de uso: orquestra domínio + infraestrutura
├── domain/              # Entidades, enums, regras puras (limiares, transições, papel)
└── infrastructure/      # BERTimbau, DetectorDeLinks, buffer, SQLAlchemy, gateway WS
tests/
├── unit/
└── integration/
```

Regra de dependência:
- `domain/` **não importa nada** de `api/`, `services/` ou `infrastructure/`, nem PyTorch, nem SQLAlchemy. Só Python puro. É onde ficam `AvaliadorDecisaoRisco`, a tabela de transições e a derivação do papel do menor.
- `services/` usa `domain/` e `infrastructure/`.
- `api/` só chama `services/`. Nada de regra de negócio dentro das rotas.

## Dependências

- PyTorch **sempre CPU**. No `requirements.txt`, use `--extra-index-url https://download.pytorch.org/whl/cpu` e `torch` (sem isso a imagem baixa a versão CUDA, com vários GB a mais).
- Banco: SQLAlchemy 2.x com SQLite. Senhas: `argon2-cffi`. JWT: `PyJWT`. PDF: `reportlab`. Settings: `pydantic-settings`.
- Não adicione Redis, Celery, PostgreSQL ou filas: o escopo não precisa.

## Configuração (variáveis de ambiente)

| Variável | Padrão | Uso |
| :--- | :--- | :--- |
| `APP_ENV` | `production` | `testing` faz a factory devolver o classificador mock |
| `MODEL_DIR` | `/models/modelo_tcc_final` | Pasta do modelo (montada somente leitura) |
| `DATABASE_URL` | `sqlite:////app/data/artemis.db` | Quatro barras: caminho absoluto dentro do volume |
| `JWT_SECRET` | (obrigatório fora de testes) | Assinatura dos tokens |
| `CORS_ORIGINS` | `http://localhost:3000` | Origem do simulador |

O `Dockerfile` executa `uvicorn src.main:app --host 0.0.0.0 --port 8000`.

## Modelo

- Carregamento preguiçoso (Virtual Proxy): os pesos só são lidos do disco na primeira predição. Nunca carregar no import nem no startup.
- `model.eval()` e inferência dentro de `torch.no_grad()`.
- Tokenizer com `truncation=True, max_length=512, return_tensors="pt"`.
- `P(nocivo)` é a probabilidade do índice 1 após `softmax` (índice 0 = `normal`, 1 = `nocivo`).
- Se a pasta do modelo não existir, falhe com mensagem clara indicando como baixá-lo. **Não** tente baixar do Hugging Face (o volume é somente leitura).
- Uma única instância do classificador para toda a aplicação.

## Estado em memória

- O buffer de contexto e a lista de incidentes "abertos para posteriores" ficam em memória, em um único processo. Rode o uvicorn com **1 worker**.
- As conexões WebSocket ficam registradas por `guardian_id` em um gerenciador em memória.
- O escalonamento (se implementado) é uma tarefa `asyncio` iniciada no `lifespan` do FastAPI, rodando a cada 60 s.

## Testes

```bash
APP_ENV=testing pytest              # tudo
APP_ENV=testing pytest tests/unit   # só unidade
```

- `conftest.py` deve: forçar `APP_ENV=testing`, usar SQLite em memória (`sqlite://` com `StaticPool`), sobrescrever a dependência do banco e criar os dados de seed (`dep-001`, `resp-001`, `resp-002`) em uma fixture.
- Testes de unidade de `domain/` não usam banco, rede nem mocks: são funções puras.
- A tabela de valor limite de `../.agents/testes.md` é o mínimo obrigatório para `AvaliadorDecisaoRisco`.
- Use `"conversa"` ou `"jogo"` como `room_type` nos testes (outros valores dão 422).
- Teste de rota protegida: gere o token chamando a rota de login com o usuário do seed.
- Uma tarefa só está concluída com todos os testes passando.
