/**
 * Project Artemis - Chat Simulator (app.js)
 * Architecture: Vanilla HTML5 / CSS3 / ES6 (No bundlers, no external dependencies)
 * Integrates with Backend POST /api/v1/predict
 * Includes native Web Crypto SHA-256 and Web Audio API alerts
 */

// Native Web Crypto API SHA-256 calculation
async function sha256Hex(text) {
  if (typeof text !== "string") {
    throw new TypeError("O texto precisa ser uma string");
  }
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(digest));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Global Application State (in-memory only, lost on reload)
const AppState = {
  dependentId: CONFIG.DEPENDENTS[0].id,
  roomType: CONFIG.DEFAULT_ROOM_TYPE,
  conversationId: generateConversationId(CONFIG.DEFAULT_ROOM_TYPE),
  isFromMinor: false,
  senderId: CONFIG.DEFAULT_SENDER_OPPONENT_ID,
  isDirect: true,
  audioAlertEnabled: true,
  mockMode: false,
  messages: [],
  lastAudit: null,
};

// Helper: Generate distinct conversation IDs
function generateConversationId(roomType) {
  const prefix = roomType === "jogo" ? "conv-game" : "conv-chat";
  const randomSuffix = Math.random().toString(36).substring(2, 8);
  const timestamp = Date.now().toString().slice(-4);
  return `${prefix}-${timestamp}-${randomSuffix}`;
}

// Web Audio API Alert Synthesizer (Works offline, no external files)
let audioCtx = null;
function playCriticalAlertSound() {
  if (!AppState.audioAlertEnabled) return;
  try {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    if (!audioCtx) {
      audioCtx = new AudioContextClass();
    }
    if (audioCtx.state === "suspended") {
      audioCtx.resume();
    }

    const now = audioCtx.currentTime;

    const osc1 = audioCtx.createOscillator();
    const gain1 = audioCtx.createGain();
    osc1.type = "sawtooth";
    osc1.frequency.setValueAtTime(880, now);
    osc1.frequency.exponentialRampToValueAtTime(1200, now + 0.15);
    gain1.gain.setValueAtTime(0.3, now);
    gain1.gain.exponentialRampToValueAtTime(0.01, now + 0.15);
    osc1.connect(gain1);
    gain1.connect(audioCtx.destination);
    osc1.start(now);
    osc1.stop(now + 0.15);

    const osc2 = audioCtx.createOscillator();
    const gain2 = audioCtx.createGain();
    osc2.type = "sine";
    osc2.frequency.setValueAtTime(950, now + 0.18);
    osc2.frequency.setValueAtTime(750, now + 0.32);
    gain2.gain.setValueAtTime(0.4, now + 0.18);
    gain2.gain.exponentialRampToValueAtTime(0.01, now + 0.45);
    osc2.connect(gain2);
    gain2.connect(audioCtx.destination);
    osc2.start(now + 0.18);
    osc2.stop(now + 0.45);
  } catch (err) {
    console.warn("Falha ao reproduzir áudio com Web Audio API:", err);
  }
}

// Local heuristic fallback for Mock Mode (Offline demo)
function simulateMockPrediction(payload) {
  const text = payload.text;
  const isGamerRoom = payload.context_metadata.room_type === "jogo";
  const urlRegex = /(https?:\/\/[^\s]+|www\.[^\s]+)/gi;
  const hasLink = urlRegex.test(text);

  let label = "normal";
  let category = "SEGURO";
  let confidence = 0.12;
  let actionRequired = "NONE";

  const criticalPhrases = [
    "inútil",
    "ninguém gosta de você",
    "devia sumir",
    "morre",
    "se mata",
    "lixo humano",
  ];
  const isCritical = criticalPhrases.some((phrase) =>
    text.toLowerCase().includes(phrase)
  );

  const commonBullyingPhrases = [
    "joga muito mal",
    "lixo sai do time",
    "noob horrível",
    "atrapalha",
    "desinstala",
  ];
  const isCommonBullying = commonBullyingPhrases.some((phrase) =>
    text.toLowerCase().includes(phrase)
  );

  if (hasLink) {
    label = "nocivo";
    category = "LINK_SUSPEITO";
    confidence = 0.82;
    actionRequired = "LOG_INCIDENT";
  } else if (isCritical) {
    label = "nocivo";
    category = "CIBERBULLYING";
    confidence = 0.94;
    actionRequired = "ALERT_PARENT_CRITICAL";
  } else if (isCommonBullying) {
    label = "nocivo";
    category = "CIBERBULLYING";
    confidence = text.includes("noob") ? 0.68 : 0.74;
    const threshold = isGamerRoom ? 0.70 : 0.50;
    actionRequired = confidence >= threshold ? "LOG_INCIDENT" : "NONE";
  }

  let detectedRole = "ESPECTADOR";
  if (payload.context_metadata.is_from_minor) {
    detectedRole = "EMISSOR";
  } else if (payload.context_metadata.is_direct) {
    detectedRole = "VITIMA";
  } else {
    detectedRole = "ESPECTADOR";
  }

  return {
    label,
    category,
    confidence,
    has_link: hasLink,
    action_required: actionRequired,
    detected_role: detectedRole,
    sha256_match: true,
    incident_id:
      actionRequired !== "NONE" ? `inc-mock-${Date.now().toString().slice(-4)}` : null,
    model_version: "BERTimbau-Mock-Heuristic",
    inference_time_ms: 18.5,
  };
}

// DOM Elements cache
const DOM = {};

function initDOMReferences() {
  DOM.dependentSelect = document.getElementById("select-dependent");
  DOM.roomTypeSelect = document.getElementById("select-room-type");
  DOM.conversationIdDisplay = document.getElementById("input-conversation-id");
  DOM.btnNewConversation = document.getElementById("btn-new-conversation");
  DOM.senderSelect = document.getElementById("select-sender");
  DOM.senderIdInput = document.getElementById("input-sender-id");
  DOM.directMessageCheckbox = document.getElementById("checkbox-direct");
  DOM.audioAlertCheckbox = document.getElementById("checkbox-audio");
  DOM.mockModeCheckbox = document.getElementById("checkbox-mock");
  DOM.chatMessages = document.getElementById("chat-messages");
  DOM.chatInput = document.getElementById("chat-input");
  DOM.btnSend = document.getElementById("btn-send");
  DOM.btnClearChat = document.getElementById("btn-clear-chat");
  DOM.apiStatusBadge = document.getElementById("api-status-badge");
  DOM.criticalFlashOverlay = document.getElementById("critical-flash-overlay");

  // Guardian Auth Elements
  DOM.guardianLoginBox = document.getElementById("guardian-login-box");
  DOM.guardianLoggedBox = document.getElementById("guardian-logged-box");
  DOM.guardianEmailInput = document.getElementById("input-guardian-email");
  DOM.guardianPasswordInput = document.getElementById("input-guardian-password");
  DOM.guardianLoginError = document.getElementById("guardian-login-error");
  DOM.btnGuardianLogin = document.getElementById("btn-guardian-login");
  DOM.guardianLoggedName = document.getElementById("guardian-logged-name");
  DOM.guardianLoggedEmail = document.getElementById("guardian-logged-email");
  DOM.btnRefreshDependents = document.getElementById("btn-refresh-dependents");
  DOM.btnGuardianLogout = document.getElementById("btn-guardian-logout");

  // Audit Footer Elements
  DOM.auditHash = document.getElementById("audit-hash");
  DOM.btnCopyHash = document.getElementById("btn-copy-hash");
  DOM.auditCategory = document.getElementById("audit-category");
  DOM.auditConfidence = document.getElementById("audit-confidence");
  DOM.auditAction = document.getElementById("audit-action");
  DOM.auditShaMatch = document.getElementById("audit-sha-match");
  DOM.auditLatency = document.getElementById("audit-latency");
  DOM.auditRole = document.getElementById("audit-role");
}

function getApiBaseUrl() {
  return (CONFIG.HEALTH_URL || "http://127.0.0.1:8000/").replace(/\/+$/, "");
}

// Populate Dependents Dropdown
function populateDependents() {
  const savedToken = sessionStorage.getItem("artemis_sim_token");
  const savedGuardianRaw = sessionStorage.getItem("artemis_sim_guardian");
  if (savedToken && savedGuardianRaw) {
    try {
      AppState.guardianToken = savedToken;
      AppState.guardian = JSON.parse(savedGuardianRaw);
      updateGuardianAuthUI(true);
      syncDependentsFromBackend();
      return;
    } catch (_) {}
  }
  updateGuardianAuthUI(false);
  renderDependentsList([]);
}

function updateGuardianAuthUI(isLoggedIn) {
  if (!DOM.guardianLoginBox || !DOM.guardianLoggedBox) return;
  if (isLoggedIn && AppState.guardian) {
    DOM.guardianLoginBox.style.display = "none";
    DOM.guardianLoggedBox.style.display = "block";
    DOM.guardianLoggedName.textContent = AppState.guardian.name || "Responsável";
    DOM.guardianLoggedEmail.textContent = AppState.guardian.email || "";
  } else {
    DOM.guardianLoginBox.style.display = "block";
    DOM.guardianLoggedBox.style.display = "none";
  }
}

async function loginGuardian() {
  const email = (DOM.guardianEmailInput?.value || "").trim();
  const password = DOM.guardianPasswordInput?.value || "";

  if (!email || !password) {
    showGuardianError("Informe o e-mail e a senha do responsável.");
    return;
  }

  hideGuardianError();
  DOM.btnGuardianLogin.disabled = true;
  DOM.btnGuardianLogin.textContent = "Conectando...";

  try {
    const res = await fetch(`${getApiBaseUrl()}/api/v1/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });

    if (!res.ok) {
      let msg = "E-mail ou senha incorretos.";
      try {
        const err = await res.json();
        if (err.detail) msg = err.detail;
      } catch (_) {}
      showGuardianError(msg);
      return;
    }

    const data = await res.json();
    AppState.guardianToken = data.access_token;
    AppState.guardian = data.guardian || { name: email, email };

    sessionStorage.setItem("artemis_sim_token", AppState.guardianToken);
    sessionStorage.setItem("artemis_sim_guardian", JSON.stringify(AppState.guardian));

    updateGuardianAuthUI(true);
    await syncDependentsFromBackend();
  } catch (err) {
    showGuardianError("Erro ao conectar na API (127.0.0.1:8000).");
  } finally {
    DOM.btnGuardianLogin.disabled = false;
    DOM.btnGuardianLogin.textContent = "Entrar para Filtrar Dependentes";
  }
}

function logoutGuardian() {
  AppState.guardianToken = null;
  AppState.guardian = null;
  sessionStorage.removeItem("artemis_sim_token");
  sessionStorage.removeItem("artemis_sim_guardian");
  updateGuardianAuthUI(false);
  renderDependentsList([]);
}

function showGuardianError(msg) {
  if (!DOM.guardianLoginError) return;
  DOM.guardianLoginError.textContent = msg;
  DOM.guardianLoginError.style.display = "block";
}

function hideGuardianError() {
  if (!DOM.guardianLoginError) return;
  DOM.guardianLoginError.textContent = "";
  DOM.guardianLoginError.style.display = "none";
}

function renderDependentsList(dependentsList) {
  const previousValue = AppState.dependentId;
  DOM.dependentSelect.innerHTML = "";

  if (!Array.isArray(dependentsList) || dependentsList.length === 0) {
    const opt = document.createElement("option");
    opt.value = "";
    opt.textContent = AppState.guardianToken
      ? "Nenhum dependente vinculado a esta conta"
      : "Faça login acima para listar os dependentes...";
    DOM.dependentSelect.appendChild(opt);
    AppState.dependentId = "";
    return;
  }

  dependentsList.forEach((dep) => {
    const opt = document.createElement("option");
    opt.value = dep.id;
    const roleTag =
      dep.is_primary === true
        ? "Primário"
        : dep.is_primary === false
        ? "Secundário"
        : "";
    const thresholdTag =
      typeof dep.common_threshold === "number"
        ? `L=${dep.common_threshold.toFixed(2)}`
        : "";
    const extra = [roleTag, thresholdTag].filter(Boolean).join(" • ");
    opt.textContent = extra
      ? `${dep.name} (${dep.id}) — ${extra}`
      : `${dep.name} (${dep.id})`;
    DOM.dependentSelect.appendChild(opt);
  });

  const stillExists = dependentsList.some((d) => d.id === previousValue);
  if (stillExists) {
    DOM.dependentSelect.value = previousValue;
    AppState.dependentId = previousValue;
  } else {
    DOM.dependentSelect.value = dependentsList[0].id;
    AppState.dependentId = dependentsList[0].id;
  }
}

async function syncDependentsFromBackend() {
  if (!AppState.guardianToken) {
    return;
  }
  try {
    const res = await fetch(`${getApiBaseUrl()}/api/v1/dependents`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${AppState.guardianToken}`,
      },
    });
    if (res.ok) {
      const deps = await res.json();
      renderDependentsList(Array.isArray(deps) ? deps : []);
    } else if (res.status === 401) {
      logoutGuardian();
    }
  } catch (_) {
    // Mantém lista atual caso haja oscilação momentânea de rede
  }
}

// Check Backend Connectivity
async function checkBackendHealth() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const res = await fetch(CONFIG.HEALTH_URL, {
      method: "GET",
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (res.ok) {
      const data = await res.json();
      DOM.apiStatusBadge.className = "status-badge online";
      DOM.apiStatusBadge.textContent = "API Online (8000)";
      DOM.apiStatusBadge.title = `Status: ${data.status}, Model loaded: ${data.model_loaded}`;
      syncDependentsFromBackend();
    } else {
      DOM.apiStatusBadge.className = "status-badge degraded";
      DOM.apiStatusBadge.textContent = "API Degradação (HTTP " + res.status + ")";
    }
  } catch (err) {
    DOM.apiStatusBadge.className = "status-badge offline";
    DOM.apiStatusBadge.textContent = "API Offline (Usar Mock)";
    DOM.apiStatusBadge.title = "Backend não respondeu em http://localhost:8000";
  }
}

// Add a bubble to chat UI
function addChatBubble(messageData, responseData, errorDetail = null) {
  const emptyState = DOM.chatMessages.querySelector(".chat-empty-state");
  if (emptyState) {
    emptyState.remove();
  }

  const bubble = document.createElement("div");
  const isMinor = messageData.is_from_minor;
  bubble.className = `chat-bubble-container ${isMinor ? "bubble-minor" : "bubble-opponent"}`;

  const timeFormatted = new Date(messageData.timestamp).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });

  const senderLabel = isMinor
    ? `Menor (${messageData.sender_id})`
    : `Adversário (${messageData.sender_id})`;

  const roomLabel = messageData.room_type === "jogo" ? "Jogo" : "Conversa";
  const channelLabel = messageData.is_direct ? "Direta (DM)" : "Grupo";

  let analysisHtml = "";
  if (responseData) {
    const categoryClass =
      responseData.category === "CIBERBULLYING"
        ? responseData.action_required === "ALERT_PARENT_CRITICAL"
          ? "pill-critical"
          : "pill-warning"
        : responseData.category === "LINK_SUSPEITO"
        ? "pill-purple"
        : "pill-safe";

    const actionClass =
      responseData.action_required === "ALERT_PARENT_CRITICAL"
        ? "pill-critical"
        : responseData.action_required === "LOG_INCIDENT"
        ? "pill-warning"
        : "pill-neutral";

    const shaMatchClass = responseData.sha256_match ? "pill-sha-ok" : "pill-sha-fail";

    analysisHtml = `
      <div class="bubble-analysis">
        <span class="analysis-pill ${categoryClass}">${responseData.category}</span>
        <span class="analysis-pill pill-confidence">P: ${(responseData.confidence * 100).toFixed(1)}%</span>
        <span class="analysis-pill ${actionClass}">Ação: ${responseData.action_required}</span>
        <span class="analysis-pill ${shaMatchClass}" title="Integridade SHA-256">${
          responseData.sha256_match ? "Hash OK" : "Hash Incorreto"
        }</span>
        <span class="analysis-pill pill-role" title="Papel detectado">${responseData.detected_role}</span>
        <span class="analysis-pill pill-latency" title="Tempo de inferência">${responseData.inference_time_ms.toFixed(1)}ms</span>
      </div>
    `;
  } else if (errorDetail) {
    analysisHtml = `
      <div class="bubble-analysis error">
        <span class="analysis-pill pill-critical">Falha no envio: ${errorDetail}</span>
      </div>
    `;
  }

  bubble.innerHTML = `
    <div class="bubble-meta">
      <span class="bubble-sender">${senderLabel}</span>
      <span class="bubble-channel">${roomLabel} &bull; ${channelLabel}</span>
      <span class="bubble-time">${timeFormatted}</span>
    </div>
    <div class="bubble-body">
      <div class="bubble-text">${escapeHtml(messageData.text)}</div>
      ${analysisHtml}
    </div>
  `;

  DOM.chatMessages.appendChild(bubble);
  DOM.chatMessages.scrollTop = DOM.chatMessages.scrollHeight;

  if (responseData && responseData.action_required === "ALERT_PARENT_CRITICAL") {
    bubble.classList.add("critical-pulse");
    triggerCriticalFlashUI();
    playCriticalAlertSound();
  }
}

// Visual screen flash for critical alerts
function triggerCriticalFlashUI() {
  if (!DOM.criticalFlashOverlay) return;
  DOM.criticalFlashOverlay.classList.remove("active");
  void DOM.criticalFlashOverlay.offsetWidth;
  DOM.criticalFlashOverlay.classList.add("active");
  setTimeout(() => {
    DOM.criticalFlashOverlay.classList.remove("active");
  }, 1200);
}

// Update Audit Footer
function updateAuditFooter(payload, responseData, rttMs) {
  DOM.auditHash.textContent = payload.message_hash;
  DOM.auditHash.title = payload.message_hash;

  if (responseData) {
    DOM.auditCategory.textContent = responseData.category;
    DOM.auditCategory.className = `audit-val ${
      responseData.category === "CIBERBULLYING"
        ? "val-danger"
        : responseData.category === "LINK_SUSPEITO"
        ? "val-purple"
        : "val-success"
    }`;

    DOM.auditConfidence.textContent = `${(responseData.confidence * 100).toFixed(1)}%`;
    DOM.auditAction.textContent = responseData.action_required;
    DOM.auditAction.className = `audit-val ${
      responseData.action_required === "ALERT_PARENT_CRITICAL"
        ? "val-danger"
        : responseData.action_required === "LOG_INCIDENT"
        ? "val-warning"
        : "val-muted"
    }`;

    DOM.auditShaMatch.textContent = responseData.sha256_match ? "Válido (Match)" : "Divergente";
    DOM.auditShaMatch.className = `audit-val ${responseData.sha256_match ? "val-success" : "val-danger"}`;

    DOM.auditLatency.textContent = `Inf: ${responseData.inference_time_ms.toFixed(1)}ms | RTT: ${rttMs}ms`;
    DOM.auditRole.textContent = responseData.detected_role;
  } else {
    DOM.auditCategory.textContent = "ERRO";
    DOM.auditCategory.className = "audit-val val-danger";
    DOM.auditConfidence.textContent = "—";
    DOM.auditAction.textContent = "—";
    DOM.auditShaMatch.textContent = "—";
    DOM.auditLatency.textContent = `${rttMs}ms`;
    DOM.auditRole.textContent = "—";
  }
}

// Main Send Action
async function sendMessage() {
  const rawText = DOM.chatInput.value;

  if (!AppState.dependentId) {
    alert("Faça login com a conta do responsável na barra lateral e selecione o dependente monitorado antes de enviar.");
    DOM.guardianEmailInput?.focus();
    return;
  }

  if (!rawText || rawText.trim().length === 0) {
    alert("Digite uma mensagem válida (não pode ser vazia ou apenas espaços).");
    DOM.chatInput.focus();
    return;
  }

  DOM.btnSend.disabled = true;
  DOM.btnSend.textContent = "Calculando...";

  const startTime = performance.now();

  try {
    const messageHash = await sha256Hex(rawText);

    const payload = {
      text: rawText,
      message_hash: messageHash,
      dependent_id: AppState.dependentId,
      context_metadata: {
        conversation_id: AppState.conversationId,
        room_type: AppState.roomType,
        sender_id: AppState.senderId,
        is_from_minor: AppState.isFromMinor,
        is_direct: AppState.isDirect,
        timestamp: new Date().toISOString(),
      },
    };

    DOM.btnSend.textContent = "Enviando...";

    let responseData = null;
    let errorDetail = null;

    if (AppState.mockMode) {
      await new Promise((r) => setTimeout(r, 60));
      responseData = simulateMockPrediction(payload);
    } else {
      try {
        const response = await fetch(CONFIG.API_URL, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify(payload),
        });

        if (response.ok) {
          responseData = await response.json();
        } else {
          let errBody = {};
          try {
            errBody = await response.json();
          } catch (_) {}
          errorDetail = errBody.detail || `Erro HTTP ${response.status} (${response.statusText})`;
        }
      } catch (networkErr) {
        console.warn("Falha de rede ao conectar à API:", networkErr);
        if (confirm("Não foi possível conectar ao Backend (http://localhost:8000).\nDeseja ativar o Modo Mock Offline para continuar a demonstração?")) {
          AppState.mockMode = true;
          DOM.mockModeCheckbox.checked = true;
          responseData = simulateMockPrediction(payload);
        } else {
          errorDetail = "Falha de conexão com http://localhost:8000 (Backend offline ou CORS).";
        }
      }
    }

    const endTime = performance.now();
    const totalRttMs = Math.round(endTime - startTime);

    addChatBubble(
      {
        text: rawText,
        sender_id: AppState.senderId,
        is_from_minor: AppState.isFromMinor,
        room_type: AppState.roomType,
        is_direct: AppState.isDirect,
        timestamp: payload.context_metadata.timestamp,
      },
      responseData,
      errorDetail
    );

    updateAuditFooter(payload, responseData, totalRttMs);

    DOM.chatInput.value = "";
    DOM.chatInput.focus();
  } catch (err) {
    console.error("Erro no processamento da mensagem:", err);
    alert(`Erro interno: ${err.message}`);
  } finally {
    DOM.btnSend.disabled = false;
    DOM.btnSend.textContent = "Enviar";
  }
}

// Utility: HTML escaping
function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// Event Listeners Registration
function registerEventListeners() {
  if (DOM.btnGuardianLogin) {
    DOM.btnGuardianLogin.addEventListener("click", loginGuardian);
  }

  if (DOM.guardianPasswordInput) {
    DOM.guardianPasswordInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        loginGuardian();
      }
    });
  }

  if (DOM.btnRefreshDependents) {
    DOM.btnRefreshDependents.addEventListener("click", syncDependentsFromBackend);
  }

  if (DOM.btnGuardianLogout) {
    DOM.btnGuardianLogout.addEventListener("click", logoutGuardian);
  }

  DOM.dependentSelect.addEventListener("change", (e) => {
    AppState.dependentId = e.target.value;
  });

  DOM.dependentSelect.addEventListener("focus", () => {
    syncDependentsFromBackend();
  });

  DOM.roomTypeSelect.addEventListener("change", (e) => {
    AppState.roomType = e.target.value;
    AppState.conversationId = generateConversationId(AppState.roomType);
    DOM.conversationIdDisplay.value = AppState.conversationId;
  });

  DOM.btnNewConversation.addEventListener("click", () => {
    AppState.conversationId = generateConversationId(AppState.roomType);
    DOM.conversationIdDisplay.value = AppState.conversationId;
  });

  DOM.senderSelect.addEventListener("change", (e) => {
    const isMinor = e.target.value === "minor";
    AppState.isFromMinor = isMinor;
    AppState.senderId = isMinor
      ? CONFIG.DEFAULT_SENDER_MINOR_ID
      : CONFIG.DEFAULT_SENDER_OPPONENT_ID;
    DOM.senderIdInput.value = AppState.senderId;
  });

  DOM.senderIdInput.addEventListener("input", (e) => {
    AppState.senderId = e.target.value.trim() || "user-anon";
  });

  DOM.directMessageCheckbox.addEventListener("change", (e) => {
    AppState.isDirect = e.target.checked;
  });

  DOM.audioAlertCheckbox.addEventListener("change", (e) => {
    AppState.audioAlertEnabled = e.target.checked;
  });

  DOM.mockModeCheckbox.addEventListener("change", (e) => {
    AppState.mockMode = e.target.checked;
  });

  DOM.btnSend.addEventListener("click", sendMessage);

  DOM.chatInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  DOM.btnClearChat.addEventListener("click", () => {
    if (confirm("Deseja limpar todo o histórico de mensagens do simulador?")) {
      DOM.chatMessages.innerHTML = `
        <div class="chat-empty-state">
          <span>Simulador pronto. Digite uma mensagem abaixo para analisar com o BERTimbau.</span>
        </div>
      `;
    }
  });

  DOM.btnCopyHash.addEventListener("click", () => {
    const hash = DOM.auditHash.textContent;
    if (hash && hash !== "—") {
      navigator.clipboard.writeText(hash).then(() => {
        DOM.btnCopyHash.textContent = "Copiado!";
        setTimeout(() => {
          DOM.btnCopyHash.textContent = "Copiar";
        }, 1500);
      });
    }
  });
}

// Initialization on DOMContentLoaded
document.addEventListener("DOMContentLoaded", () => {
  initDOMReferences();
  populateDependents();
  registerEventListeners();

  DOM.conversationIdDisplay.value = AppState.conversationId;
  DOM.senderIdInput.value = AppState.senderId;

  checkBackendHealth();
  setInterval(checkBackendHealth, 10000);
});

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    sha256Hex,
    simulateMockPrediction,
    generateConversationId,
  };
}
