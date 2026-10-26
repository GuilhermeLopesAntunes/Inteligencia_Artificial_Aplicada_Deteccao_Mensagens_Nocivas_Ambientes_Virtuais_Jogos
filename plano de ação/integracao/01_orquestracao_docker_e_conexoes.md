# Integração - Etapa 1: Orquestração Docker Compose e Redes

> **Objetivo:** Orquestrar a inicialização simultânea dos serviços e configurar as permissões de rede entre Simulador, Backend e App Android.

---

## 1. Arquivos a Criar/Atualizar
- `docker-compose.yml`
- `.env` / `.env.example`
- `frontend/android/app/src/main/AndroidManifest.xml`
- `frontend/lib/config.dart`

---

## 2. Detalhamento dos Componentes

### 2.1. Configuração do `docker-compose.yml`
```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    container_name: artemis_backend
    ports:
      - "8000:8000"
    environment:
      - APP_ENV=production
      - MODEL_DIR=/models/modelo_tcc_final
      - DATABASE_URL=sqlite:////app/data/artemis.db
      - JWT_SECRET=artemis_super_secret_jwt_key_2026
      - CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
    volumes:
      - ./models:/models:ro
      - ./backend/data:/app/data
    restart: unless-stopped

  simulator:
    build: ./simulator
    container_name: artemis_simulator
    ports:
      - "3000:80"
    restart: unless-stopped
```

### 2.2. Configuração de Rede no App Android (`AndroidManifest.xml`)
* Permitir tráfego HTTP sem SSL (Cleartext Traffic) para comunicação com o backend em ambiente de teste local:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:label="Artemis Parental"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        ...
    </application>
</manifest>
```

### 2.3. Resolução de URLs de Conexão
* **Simulador Web (Browser do Host):**
  * Conecta em `http://localhost:8000/api/v1/predict`
* **App Flutter no Emulador Android Oficial:**
  * Conecta em `http://10.0.2.2:8000` (IP loopback do host no Android Emulator).
* **App Flutter em Dispositivo Físico:**
  * Conecta via IP da rede local (ex: `http://192.168.1.50:8000`).

---

## 3. Critérios de Aceitação da Etapa
- [ ] `docker compose up -d` sobe os contêineres de backend e simulador sem conflitos de porta.
- [ ] O simulador consegue disparar requisições para a API sem bloqueios de CORS.
- [ ] O app Flutter no emulador conecta com sucesso na API e no WebSocket.
