from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()

# Define o formato do dado que o Flutter vai enviar para a API
class TextPayload(BaseModel):
    text: str

# Define o formato da resposta que a API vai devolver para o Flutter
class PredictionResponse(BaseModel):
    text: str
    label: str
    confidence: float

@router.post("/predict", response_model=PredictionResponse)
def predict_message(payload: TextPayload):
    """
    Endpoint que recebe um texto do frontend e retorna a classificação do modelo.
    """
    if not payload.text.strip():
        raise HTTPException(status_code=400, detail="O texto não pode estar vazio.")
    
    # Placeholder: Aqui entrará a lógica onde carrega o modelo treinado
    # na pasta /scripts e passa o texto por ele.
    
    # Exemplo de classificação
    resultado_simulado = {
        "text": payload.text,
        "label": "normal",  
        "confidence": 0.95
    }
    
    return resultado_simulado