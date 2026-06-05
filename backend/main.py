from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1 import predict

app = FastAPI(
    title="API de Detecção e Análise",
    description="Backend para processamento de dados e inferência de modelos de IA",
    version="1.0.0"
)

origins = [
    "http://localhost",
    "http://localhost:8080", 
    "http://localhost:3000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"], 
    allow_headers=["*"],  
)


@app.get("/", tags=["Health Check"])
def read_root():
    return {"status": "online", "message": "FastAPI rodando com sucesso!"}

app.include_router(predict.router, prefix="/api/v1", tags=["Inference"])