import os
from functools import lru_cache
from pathlib import Path

from src.api.core.config import settings

# 0 = mensagem normal, 1 = mensagem nociva/ofensiva
LIMIAR_LABEL = 0.50
MAX_LENGTH = 512


def _model_dir() -> Path:
    model_dir = Path(os.getenv("MODEL_DIR", str(settings.model_dir)))
    if not (model_dir / "model.safetensors").exists():
        raise RuntimeError(
            f"Modelo não encontrado em '{model_dir}'. Baixe 'GuilhermeLA/modelo-tcc-final' "
            "do Hugging Face (hf download GuilhermeLA/modelo-tcc-final --local-dir models/modelo_tcc_final) "
            "e monte a pasta em MODEL_DIR."
        )
    return model_dir


@lru_cache(maxsize=1)
def get_model():
    """Carregamento preguiçoso: só lê os pesos na primeira predição."""
    import torch
    from safetensors.torch import load as st_load
    from transformers import (
        AutoConfig,
        AutoModelForSequenceClassification,
        AutoTokenizer,
    )

    model_dir = _model_dir()
    tokenizer = AutoTokenizer.from_pretrained(str(model_dir))
    config = AutoConfig.from_pretrained(str(model_dir))
    with open(model_dir / "model.safetensors", "rb") as sf:
        state_dict = st_load(sf.read())
    model = AutoModelForSequenceClassification.from_config(config)
    model.load_state_dict(state_dict, strict=True)
    model.eval()
    return tokenizer, model


def is_model_loaded() -> bool:
    return get_model.cache_info().currsize > 0


def classify_text(text: str) -> tuple[str, float]:
    """Retorna (label, P(nocivo)). `confidence` é sempre P(nocivo), nunca a do rótulo previsto."""
    import torch

    tokenizer, model = get_model()
    inputs = tokenizer(
        text, truncation=True, max_length=MAX_LENGTH, return_tensors="pt"
    )
    with torch.no_grad():
        logits = model(**inputs).logits
    p_nocivo = float(torch.softmax(logits, dim=-1)[0][1].item())
    label = "nocivo" if p_nocivo >= LIMIAR_LABEL else "normal"
    return label, p_nocivo
