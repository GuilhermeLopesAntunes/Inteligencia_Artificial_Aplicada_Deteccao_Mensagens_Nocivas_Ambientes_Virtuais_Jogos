/**
 * Project Artemis - Chat Simulator Configuration
 * Conforms to .agents/contrato-api.md and .agents/regras-de-negocio.md
 */

const CONFIG = {
  // Backend API endpoint for predictions (127.0.0.1 avoids Windows IPv6 ::1 2s timeout)
  API_URL: "http://127.0.0.1:8000/api/v1/predict",
  HEALTH_URL: "http://127.0.0.1:8000/",

  // Pre-seeded dependents from backend seed (backend/src/seed.py)
  DEPENDENTS: [
    { id: "dep-001", name: "Lucas", common_threshold: 0.50 },
    { id: "dep-002", name: "Ana", common_threshold: 0.50 }
  ],

  // Default configuration
  DEFAULT_ROOM_TYPE: "jogo",
  DEFAULT_SENDER_MINOR_ID: "user-menor-01",
  DEFAULT_SENDER_OPPONENT_ID: "user-adversario-09",

  // 5 Quick-demo Presets for the Academic Defense Committee (TCC 20/10/2026)
  PRESETS: [
    {
      id: "safe",
      name: "1. Mensagem Segura",
      badge: "SEGURO",
      badgeClass: "badge-safe",
      description: "Mensagem amigável de jogo (P < 0.50)",
      text: "eae vamos jogar uma partida agora?",
      roomType: "jogo",
      isFromMinor: false,
      senderId: "user-adversario-09",
      isDirect: true,
      expectedCategory: "SEGURO",
      expectedAction: "NONE"
    },
    {
      id: "cyberbullying_common",
      name: "2. Ciberbullying Comum",
      badge: "COMUM (0.50 ≤ P ≤ 0.84)",
      badgeClass: "badge-warning",
      description: "Ofensa moderada em chat comum (P ∈ [0.50, 0.84])",
      text: "você joga muito mal lixo sai do time que você só atrapalha",
      roomType: "conversa",
      isFromMinor: false,
      senderId: "user-adversario-09",
      isDirect: true,
      expectedCategory: "CIBERBULLYING",
      expectedAction: "LOG_INCIDENT"
    },
    {
      id: "gamer_mode",
      name: "3. Modo Gamer (0.70)",
      badge: "MODO GAMER",
      badgeClass: "badge-info",
      description: "Ambiente de jogo com limiar de tolerância calibrado para 0.70",
      text: "seu noob horrível desiste de jogar e desinstala esse jogo",
      roomType: "jogo",
      isFromMinor: false,
      senderId: "user-adversario-09",
      isDirect: false,
      expectedCategory: "CIBERBULLYING",
      expectedAction: "LOG_INCIDENT"
    },
    {
      id: "critical_attack",
      name: "4. Ataque Crítico",
      badge: "CRÍTICO (P ≥ 0.85)",
      badgeClass: "badge-danger",
      description: "Ofensa grave que dispara alerta sonoro e notificação prioritária imediata",
      text: "Você é um inútil, ninguém gosta de você, devia sumir daqui",
      roomType: "jogo",
      isFromMinor: false,
      senderId: "user-adversario-09",
      isDirect: true,
      expectedCategory: "CIBERBULLYING",
      expectedAction: "ALERT_PARENT_CRITICAL"
    },
    {
      id: "suspicious_link",
      name: "5. Link Suspeito",
      badge: "LINK SUSPEITO",
      badgeClass: "badge-purple",
      description: "Tentativa de phishing/golpe de moedas com URL externa",
      text: "entra nesse site https://free-skins.xyz para ganhar moedas",
      roomType: "jogo",
      isFromMinor: false,
      senderId: "user-adversario-09",
      isDirect: true,
      expectedCategory: "LINK_SUSPEITO",
      expectedAction: "LOG_INCIDENT"
    }
  ]
};

// Export for Node.js test environments if applicable
if (typeof module !== "undefined" && module.exports) {
  module.exports = CONFIG;
}
