from functools import lru_cache

import torch
from huggingface_hub import snapshot_download
from transformers import AutoModelForSequenceClassification, AutoTokenizer

from app.api.core.config import settings

# 0 = mensagem normal, 1 = mensagem nociva/ofensiva
ID2LABEL = {0: "normal", 1: "nocivo"}


def _ensure_model_downloaded() -> str:
    model_dir = settings.model_local_dir
    if not (model_dir / "model.safetensors").exists():
        model_dir.mkdir(parents=True, exist_ok=True)
        snapshot_download(repo_id=settings.hf_model_repo_id, local_dir=str(model_dir))
    return str(model_dir)


@lru_cache(maxsize=1)
def get_model():
    model_dir = _ensure_model_downloaded()
    tokenizer = AutoTokenizer.from_pretrained(model_dir)
    model = AutoModelForSequenceClassification.from_pretrained(model_dir)
    model.eval()
    return tokenizer, model


def classify_text(text: str) -> tuple[str, float]:
    tokenizer, model = get_model()
    inputs = tokenizer(text, return_tensors="pt", truncation=True, padding=True)
    with torch.no_grad():
        logits = model(**inputs).logits
    probs = torch.softmax(logits, dim=-1)[0]
    predicted_id = int(torch.argmax(probs).item())
    return ID2LABEL[predicted_id], float(probs[predicted_id])
