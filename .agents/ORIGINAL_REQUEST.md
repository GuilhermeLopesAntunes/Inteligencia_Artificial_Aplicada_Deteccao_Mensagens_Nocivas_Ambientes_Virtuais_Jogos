# Original User Request

## 2026-10-09T19:45:35Z

Use uma equipe com agentes separados para Backend, Frontend e Simulador trabalhando em paralelo; um agente de Integração que só começa depois que Backend e Frontend terminarem; e um agente de Documentação que acompanha todo o processo.

Implementar o MVP do **Project Artemis** — sistema de controle parental que detecta ciberbullying em mensagens de jogos/chats usando BERTimbau (CPU) — para apresentação de TCC à banca em 20/10/2026. O repositório já contém as especificações e um plano de ação detalhado por eixo; a tarefa é transformá-los em software funcionando ponta a ponta.

Working directory: `C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos`
Integrity mode: development

## Fontes de verdade (já no repositório)
- `.agents/` — `regras-de-negocio.md`, `contrato-api.md`, `arquitetura.md`, `testes.md`, `requisitos.md`, `casos-de-uso.md`, `modelagem-uml.md`, `padroes-de-projeto.md`
- `AGENTS.md` (raiz) e `AGENTS.md` de cada módulo (`backend/`, `simulator/`)
- `plano de ação/` — um README mestre + tasks `.md` numeradas por eixo: `backend/`, `frontend/`, `simulador/`, `integracao/`

Em caso de conflito, `.agents/regras-de-negocio.md` e `.agents/contrato-api.md` prevalecem. Estado atual: backend tem apenas um esqueleto (`src/main.py`, `api/v1/predict.py`, model loader com download do Hugging Face); frontend tem só `main.dart`; simulador tem só Dockerfile e AGENTS.md; a pasta `models/` está vazia (o checkpoint é `GuilhermeLA/modelo-tcc-final` no Hugging Face).

## Requirements

### R1. Backend
Implementar o backend conforme `plano de ação/backend/` (tasks 01–05), cobrindo os casos de uso essenciais do MVP: UC-18, UC-01/10/11/13, UC-02, UC-09, UC-03, UC-04, UC-17. Deve expor exatamente o contrato de `.agents/contrato-api.md`. Casos de uso "se sobrar tempo" (UC-06/12, UC-07, UC-08) são opcionais e só depois de todo o essencial estar verde.

### R2. Frontend (App Flutter Android)
Implementar o app conforme `plano de ação/frontend/` (tasks 01–05), funcionando primeiro de forma desacoplada (modo mock) e depois apto a usar a API real.

### R3. Simulador de Chat Web
Implementar o simulador conforme `plano de ação/simulador/` (tasks 01–03): HTML/CSS/JS puros, SHA-256 no navegador, cenários rápidos de demonstração.

### R4. Integração ponta a ponta
Somente após Backend e Frontend concluídos, conectar os três módulos conforme `plano de ação/integracao/` (tasks 01–04), incluindo o roteiro E2E e o checklist final do MVP. O modelo real deve ser usado (download do Hugging Face permitido).

### R5. Documentação contínua
Durante todo o processo, manter:
- README e guia de execução atualizados (como subir tudo com Docker, rodar o app no emulador Android, rodar os testes);
- documentação técnica da API e da arquitetura sincronizada com o código implementado;
- material de apoio para a monografia e a banca: diagramas, resultados das suítes de teste e métricas medidas (latência de inferência, latência ponta a ponta).

### R6. Ambiente e versionamento
Todo o trabalho deve ser feito numa branch Git nova (não commitar na branch atual nem fazer merge); o usuário revisa e faz o merge. Ferramentas disponíveis na máquina (Windows): Python 3.11+, Docker Desktop, Flutter SDK, Android Studio/emulador e acesso à internet (Hugging Face, pip, pub).

## Acceptance Criteria

### Backend
- [ ] `APP_ENV=testing pytest` passa 100%, incluindo testes BVA de todos os limiares (0.50/0.84, Modo Gamer 0.70, crítico 0.85)
- [ ] Uvicorn sobe em < 2 s sem carregar os pesos do modelo no boot (lazy loading)
- [ ] Todos os endpoints de `.agents/contrato-api.md` existem no OpenAPI com schemas compatíveis (verificado por teste automatizado que compara rotas/campos)

### Frontend
- [ ] `flutter analyze` sem erros e `flutter test` 100% verde
- [ ] `flutter build apk --debug` conclui com sucesso
- [ ] Modo mock: todas as telas navegáveis sem chamadas de rede; evento crítico simulado dispara notificação local (coberto por teste)

### Simulador
- [ ] Hash SHA-256 do navegador idêntico ao de uma ferramenta de linha de comando para os textos de teste (incluindo acentos e emoji), verificado por teste automatizado
- [ ] Payload enviado valida contra o schema de `POST /api/v1/predict`

### Integração
- [ ] `docker compose up` sobe backend + simulador com um único comando
- [ ] Teste E2E automatizado com o modelo real: mensagem crítica enviada no formato do simulador → incidente persistido → evento `incident.critical` recebido via WebSocket; mensagem neutra → nenhum incidente
- [ ] Latência de inferência em CPU measured e registrada (meta ≤ 350 ms) e fluxo ponta a ponta < 2 s
- [ ] PDF do relatório gerado contém o hash SHA-256 que confere com o calculado no navegador
- [ ] Checklist de `plano de ação/integracao/04_checklist_final_mvp_tcc.md` preenchido com evidência para cada item

### Documentação
- [ ] Seguindo apenas o README, um revisor independente consegue subir o sistema e rodar todas as suítes de teste sem passos não documentados
- [ ] Cada endpoint implementado aparece na documentação da API com os mesmos campos do código
- [ ] Material para a banca contém resultados reais das suítes de teste e métricas medidas (não estimadas)


## Follow-up — 2026-10-09T20:26:13Z

Houve um restart do servidor e todos os subagentes e crons foram parados. Por favor, retome a operação: verifique o estado atual da branch `feature/mvp-tcc-artemis` (o que já foi escrito/commitado por cada eixo), reviva o Project Orchestrator e os especialistas (Backend, Frontend, Simulador, Documentação) a partir de onde pararam, e reagende os crons de monitoramento.

NOVA REGRA DO USUÁRIO (vale para todos os agentes, propague para orquestrador e workers):
- Autonomia total: NÃO pergunte nada ao usuário. Execute qualquer comando de leitura, escrita, instalação, build, teste, Docker, Flutter, pip, git etc. sem pedir confirmação. Tome as decisões necessárias e siga em frente.
- ÚNICA proibição: nunca fazer push/commit/merge na `main` (nem na branch principal) do GitHub. Commits e pushes são permitidos somente em branches criadas pela equipe (ex.: `feature/mvp-tcc-artemis` ou sub-branches dela).

O restante do escopo e dos critérios de aceitação permanece igual ao prompt original (`.agents/ORIGINAL_REQUEST.md`).
