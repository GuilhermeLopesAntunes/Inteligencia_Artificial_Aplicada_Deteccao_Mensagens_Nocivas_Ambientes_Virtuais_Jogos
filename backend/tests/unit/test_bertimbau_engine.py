import time
from src.api.core.model_loader import classify_text, get_model, is_model_loaded
from src.infrastructure.bertimbau_engine import (
    BERTimbauEngineProxy,
    ClassificadorFactory,
    MockClassificadorStrategy,
    RealBERTimbauEngine,
)


def test_mock_classificador_strategy_e_proxy():
    mock = MockClassificadorStrategy(default_prob=0.12, overrides={"ataque": 0.91})
    assert mock.predict_proba("bom dia") == 0.12
    assert mock.predict_proba("isso é um ataque") == 0.91

    factory_inst = ClassificadorFactory.criar("testing")
    assert isinstance(factory_inst, MockClassificadorStrategy)


def test_lazy_loading_e_invariantes_modelo_bertimbau_real():
    """
    Valida a Seção 4.1 de INTEGRACAO_BACKEND_BERT.md:
    - Teste unitário do loader: is_model_loaded() inicia False e muda para True após a 1ª inferência.
    - Invariantes numéricas: P(nocivo) pertence a [0.0, 1.0].
    - Mensagens inócuas (ex: 'bom dia amigo, vamos jogar'): P(nocivo) < 0.50 ('normal').
    - Mensagens tóxicas explícitas: P(nocivo) >= 0.50 ('nocivo').
    """
    get_model.cache_clear()
    assert is_model_loaded() is False

    # 1. Inferência em mensagem inócua dispara o carregamento lazy
    t0 = time.perf_counter()
    label_inocuo, prob_inocuo = classify_text("bom dia amigo, vamos jogar")
    elapsed_ms = (time.perf_counter() - t0) * 1000.0

    assert is_model_loaded() is True
    assert isinstance(prob_inocuo, float)
    assert 0.0 <= prob_inocuo <= 1.0
    assert prob_inocuo < 0.50
    assert label_inocuo == "normal"
    assert elapsed_ms > 0

    # 2. Inferência em mensagem tóxica (com modelo já em cache RAM)
    t1 = time.perf_counter()
    label_toxico, prob_toxico = classify_text("Você é um inútil, ninguém gosta de você")
    cached_inference_ms = (time.perf_counter() - t1) * 1000.0

    assert 0.0 <= prob_toxico <= 1.0
    assert prob_toxico >= 0.50
    assert label_toxico == "nocivo"
    assert cached_inference_ms < 2000.0  # Rápido em CPU com cache carregado

    # 3. Verificação via RealBERTimbauEngine e BERTimbauEngineProxy
    proxy = BERTimbauEngineProxy()
    prob_proxy = proxy.predict_proba("seu lixo idiota morra")
    assert proxy.is_loaded is True
    assert 0.50 <= prob_proxy <= 1.0


def test_resiliencia_entradas_excepcionais_truncamento_512_tokens_e_emojis():
    """
    Valida a Seção 4.3 de INTEGRACAO_BACKEND_BERT.md:
    - Strings longas (> 512 tokens) devem ser truncadas sem estourar memória.
    - Caracteres especiais, emojis e pontuações repetidas não devem quebrar o pipeline.
    """
    engine = RealBERTimbauEngine()

    # Texto longo com mais de 700 palavras (> 512 subwords/tokens)
    texto_longo = " ".join(["vamos jogar tranquilo amigo"] * 200)
    prob_longo = engine.predict_proba(texto_longo)
    assert isinstance(prob_longo, float)
    assert 0.0 <= prob_longo <= 1.0

    # Caracteres especiais, emojis e pontuações repetidas
    texto_emojis = "🎮🔥💀 Olá!!! @#$%^&*()_+-=[]{}|;':\",./<>? 🚀✨"
    prob_emojis = engine.predict_proba(texto_emojis)
    assert isinstance(prob_emojis, float)
    assert 0.0 <= prob_emojis <= 1.0
