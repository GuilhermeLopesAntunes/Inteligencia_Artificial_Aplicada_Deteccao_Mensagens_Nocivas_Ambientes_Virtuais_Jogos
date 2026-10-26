# Plano de Ação: Integração e Validação End-to-End

> **Módulo:** Integração Global de Sistemas  
> **Objetivo:** Conectar o Simulador Web, o Backend FastAPI e o App Flutter Parental, validando a arquitetura completa e a entrega do MVP.

---

## 1. Visão Geral da Integração
A fase de integração une os três pilares construídos de forma autônoma:
1. **Origem:** O **Simulador Web** gera e assina mensagens criptograficamente via SHA-256 e envia via REST.
2. **Processamento:** O **Backend FastAPI** executa a inferência com BERTimbau em CPU, aplica as regras de negócio puras, persiste os dados no SQLite e notifica os responsáveis via WebSocket.
3. **Destino:** O **App Flutter** recebe as notificações em tempo real, reproduz alertas com áudio, permite a gestão de incidentes pelos pais e emite relatórios PDF periciais.

---

## 2. Roteiro Passo a Passo de Implementação

### 📄 [Etapa 1: Orquestração Docker Compose e Redes](01_orquestracao_docker_e_conexoes.md)
* Ajuste e validação do `docker-compose.yml`.
* Configuração de CORS no backend para permitir requisições do Simulador (`http://localhost:3000`).
* Configuração de permissões de rede no Flutter Android (`android:usesCleartextTraffic="true"` e roteamento para `http://10.0.2.2:8000`).

### 📄 [Etapa 2: Roteiro de Testes End-to-End (E2E)](02_roteiro_de_testes_e2e.md)
* Validação do fluxo completo:
  1. Login do responsável no App Flutter e estabelecimento da conexão WebSocket.
  2. Envio de mensagem crítica no Simulador.
  3. Recepção imediata do alerta sonoro no App Flutter.
  4. Visualização do incidente com contexto anterior e posterior.
  5. Atualização de status e verificação da sincronização em tempo real.

### 📄 [Etapa 3: Auditoria SHA-256 e Relatório PDF](03_auditoria_sha256_e_relatorio_pdf.md)
* Validação da cadeia de custódia da evidência:
  * Comparação entre o hash gerado pelo navegador e o verificado pelo backend.
  * Geração e abertura do relatório pericial em PDF no aplicativo móvel.

### 📄 [Etapa 4: Checklist Final do MVP para o TCC](04_checklist_final_mvp_tcc.md)
* Validação de todos os Casos de Uso prioritários (UC-01, UC-02, UC-03, UC-04, UC-09, UC-17, UC-18).
* Medição da latência de inferência em CPU (meta $\le 350$ms).
* Roteiro padronizado de apresentação para a banca examinadora.

---

## 3. Critérios de Conclusão do Projeto
- [ ] Todo o ecossistema sobe com um único comando `docker compose up`.
- [ ] O fluxo completo do simulador até o celular do responsável opera com latência $< 2$ segundos.
- [ ] O relatório PDF é exportado com sucesso com os dados de integridade preservados.
