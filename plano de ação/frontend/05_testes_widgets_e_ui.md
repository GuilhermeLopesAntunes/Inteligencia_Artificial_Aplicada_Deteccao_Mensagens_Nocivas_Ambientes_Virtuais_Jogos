# Frontend - Etapa 5: Testes de Widgets e UI

> **Objetivo:** Garantir a estabilidade da interface gráfica e o correto fluxo de navegação através de testes automatizados de widgets em Dart/Flutter.

---

## 1. Arquivos a Criar/Atualizar
- `frontend/test/widget_test.dart`
- `frontend/test/feed_screen_test.dart`
- `frontend/test/detail_screen_test.dart`
- `frontend/test/config_screen_test.dart`

---

## 2. Detalhamento dos Testes de Interface

### 2.1. Teste de Renderização do Feed (`test/feed_screen_test.dart`)
* Injeta o `MockApiService` configurado com 2 incidentes (um crítico e um comum).
* Verifica a exibição dos textos, badges de severidade e filtros por dependente.
* Simula toque no card de incidente e verifica se a rota de navegação é chamada.

### 2.2. Teste da Tela de Detalhes (`test/detail_screen_test.dart`)
* Verifica se a chamada `markIncidentViewed` é executada na montagem do widget.
* Valida a exibição dos balões de contexto anterior e posterior.
* Simula clique no botão de alteração de status e valida se as opções renderizadas batem com `allowed_transitions`.
* Valida se o botão de exclusão só é renderizado quando `is_primary == true`.

### 2.3. Teste da Tela de Calibração (`test/config_screen_test.dart`)
* Valida a restrição do Slider nos limites [0.50, 0.84].
* Simula a alteração do valor do slider e o clique no botão "Salvar".

---

## 3. Comandos de Execução dos Testes
```bash
# Executar todos os testes do Flutter
flutter test

# Executar com relatório detalhado
flutter test --reporter expanded
```

---

## 4. Critérios de Aceitação da Etapa
- [ ] 100% dos testes de widgets executando sem erros e sem acoplamento com rede real.
- [ ] Renderização testada em diferentes tamanhos de tela Android.
