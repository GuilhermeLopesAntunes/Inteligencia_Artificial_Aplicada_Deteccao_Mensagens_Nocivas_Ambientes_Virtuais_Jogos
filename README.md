# Inteligência Artificial Aplicada Detecção de Mensagens Nocivas em Ambientes Virtuais de Jogos
Repositório focado no desenvolvimento no Trabalho de Conclusão de Curso da Universidade Estadual de Montes Claros, focando em nteligência Artificial Aplicada à Detecção de Mensagens Nocivas em Ambientes Virtuais de Jogos Digitais 

Este repositório contém a estrutura de um projeto full-stack padrão monorepo, separando as responsabilidades de desenvolvimento, produção e ciência de dados em diretórios distintos.

## 🏗️ Arquitetura

O projeto é dividido em três pilares principais:

- **`/backend`**: API desenvolvida em **Python + FastAPI**. Responsável pela lógica de negócios, regras de validação, servir o modelo em produção e comunicação com o banco de dados.
- **`/frontend`**: Aplicação cliente desenvolvida em **Flutter**. Responsável pela interface com o usuário.
- **`/scripts`**: Ambiente isolado para engenharia de dados e Machine Learning. Contém os scripts de raspagem/limpeza de dados, engenharia de recursos (feature engineering), treinamento, validação e exportação dos modelos.

## 🐳 Orquestração (Docker)

O ambiente de desenvolvimento da API é gerenciado via **Docker Compose**.

### Como iniciar o ambiente base

Por enquanto, o arquivo `docker-compose.yml` na raiz gerencia o container da API. Quando o `Dockerfile` do backend estiver configurado, basta rodar:

```bash
docker-compose up --build