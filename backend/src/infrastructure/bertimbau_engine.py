import os
from abc import ABC, abstractmethod
from typing import Dict, Optional, Tuple

from src.api.core.config import settings
from src.api.core.model_loader import (
    LIMIAR_LABEL,
    MAX_LENGTH,
    classify_text as _real_classify_text,
    get_model,
    is_model_loaded as _real_is_model_loaded,
)


class ClassificadorStrategy(ABC):
    """Interface Strategy para classificadores de toxicidade/ciberbullying."""

    @abstractmethod
    def predict_probability(self, texto: str) -> float:
        """Retorna a probabilidade P(nocivo) estritamente entre 0.0 e 1.0."""
        pass

    def predict_proba(self, texto: str) -> float:
        return self.predict_probability(texto)


class RealBERTimbauEngine(ClassificadorStrategy):
    """Engine real do BERTimbau operando em CPU com truncamento seguro em 512 tokens."""

    def __init__(self, tokenizer=None, model=None):
        self._tokenizer = tokenizer
        self._model = model

    def _ensure_loaded(self):
        if self._tokenizer is None or self._model is None:
            self._tokenizer, self._model = get_model()

    def tokenizar(self, texto: str):
        self._ensure_loaded()
        return self._tokenizer(
            texto,
            truncation=True,
            max_length=MAX_LENGTH,
            return_tensors="pt",
        )

    def predict_probability(self, texto: str) -> float:
        if self._tokenizer is not None and self._model is not None:
            import torch

            inputs = self.tokenizar(texto)
            with torch.no_grad():
                logits = self._model(**inputs).logits
            return float(torch.softmax(logits, dim=-1)[0][1].item())
        _, p_nocivo = _real_classify_text(texto)
        return p_nocivo


class BERTimbauEngineProxy(ClassificadorStrategy):
    """Virtual Proxy (Lazy Loading) que posterga a instanciação do modelo real até a primeira predição."""

    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or str(settings.model_dir)
        self._real_engine: Optional[RealBERTimbauEngine] = None

    @property
    def is_loaded(self) -> bool:
        return self._real_engine is not None or _real_is_model_loaded()

    def _get_real_engine(self) -> RealBERTimbauEngine:
        if self._real_engine is None:
            tokenizer, model = get_model()
            self._real_engine = RealBERTimbauEngine(tokenizer=tokenizer, model=model)
        return self._real_engine

    def predict_probability(self, texto: str) -> float:
        engine = self._get_real_engine()
        return engine.predict_probability(texto)


class MockClassificadorStrategy(ClassificadorStrategy):
    """Classificador determinístico leve para execução de testes automatizados (APP_ENV=testing)."""

    CRITICAL_KEYWORDS = (
        "inútil",
        "inutil",
        "ninguém gosta",
        "ninguem gosta",
        "lixo",
        "morra",
        "se mata",
        "suma daqui",
        "horrível",
        "horrivel",
        "idiota",
        "imbecil",
        "retardado",
        "nojento",
        "aberração",
        "aberracao",
    )
    MODERATE_KEYWORDS = (
        "joga muito mal",
        "sai do time",
        "noob",
        "fraco",
        "ruim demais",
        "patético",
        "patetico",
        "burro",
        "feio",
        "chato",
    )

    def __init__(
        self,
        default_prob: Optional[float] = None,
        overrides: Optional[Dict[str, float]] = None,
    ):
        self.default_prob = default_prob
        self.overrides = overrides or {}

    def predict_probability(self, texto: str) -> float:
        lower = texto.lower()
        for k, v in self.overrides.items():
            if k.lower() in lower:
                return float(v)
        if self.default_prob is not None:
            return float(self.default_prob)
        if any(k in lower for k in self.CRITICAL_KEYWORDS):
            return 0.93
        if any(k in lower for k in self.MODERATE_KEYWORDS):
            return 0.65
        return 0.05


class ClassificadorFactory(ABC):
    @abstractmethod
    def criar_classificador(self) -> ClassificadorStrategy:
        pass

    @classmethod
    def criar(cls, env: Optional[str] = None) -> ClassificadorStrategy:
        target_env = env or os.getenv("APP_ENV", settings.app_env)
        if target_env == "testing":
            return MockClassificadorFactory().criar_classificador()
        return BERTimbauFactory().criar_classificador()


class BERTimbauFactory(ClassificadorFactory):
    def __init__(self, model_dir: Optional[str] = None):
        self.model_dir = model_dir or str(settings.model_dir)

    def criar_classificador(self) -> ClassificadorStrategy:
        return _singleton_proxy


class MockClassificadorFactory(ClassificadorFactory):
    def criar_classificador(self) -> ClassificadorStrategy:
        return _singleton_mock


_singleton_proxy = BERTimbauEngineProxy()
_singleton_mock = MockClassificadorStrategy()


def get_classificador_factory() -> ClassificadorFactory:
    env = os.getenv("APP_ENV", settings.app_env)
    if env == "testing":
        return MockClassificadorFactory()
    return BERTimbauFactory()


def get_classificador() -> ClassificadorStrategy:
    return get_classificador_factory().criar_classificador()


def is_model_loaded() -> bool:
    return _singleton_proxy.is_loaded


def classify_text(text: str) -> Tuple[str, float]:
    """
    Fachada de inferência para o serviço de aplicação.
    Em produção, utiliza o BERTimbauEngineProxy (que delega a model_loader.classify_text).
    Em ambiente de teste (APP_ENV=testing), utiliza o MockClassificadorStrategy,
    a menos que FORCE_REAL_MODEL=1 esteja definido.
    """
    env = os.getenv("APP_ENV", settings.app_env)
    force_real = os.getenv("FORCE_REAL_MODEL", "0") == "1"
    if env == "testing" and not force_real:
        p_nocivo = _singleton_mock.predict_probability(text)
        label = "nocivo" if p_nocivo >= LIMIAR_LABEL else "normal"
        return label, p_nocivo

    return _real_classify_text(text)


__all__ = [
    "ClassificadorStrategy",
    "RealBERTimbauEngine",
    "BERTimbauEngineProxy",
    "MockClassificadorStrategy",
    "ClassificadorFactory",
    "BERTimbauFactory",
    "MockClassificadorFactory",
    "get_classificador_factory",
    "get_classificador",
    "classify_text",
    "is_model_loaded",
]