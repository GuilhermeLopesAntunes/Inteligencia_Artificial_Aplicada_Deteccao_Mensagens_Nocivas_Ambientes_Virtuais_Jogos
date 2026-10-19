from datetime import datetime, timedelta, timezone
from src.infrastructure.in_memory_buffer import InMemoryBuffer, MensagemBufferItem


def _make_item(text: str, ts: datetime) -> MensagemBufferItem:
    return MensagemBufferItem(
        text=text,
        sender_id="user-1",
        is_from_minor=False,
        timestamp=ts,
    )


def test_buffer_circular_maxlen_3():
    buf = InMemoryBuffer(maxlen=3)
    t0 = datetime(2026, 4, 12, 18, 0, 0, tzinfo=timezone.utc)

    for i in range(1, 6):
        buf.adicionar_mensagem("conv-1", _make_item(f"msg-{i}", t0 + timedelta(seconds=i)))

    contexto = buf.obter_contexto_anterior("conv-1")
    assert len(contexto) == 3
    assert [m["text"] for m in contexto] == ["msg-3", "msg-4", "msg-5"]


def test_contexto_posterior_ate_3_mensagens_dentro_de_10_minutos():
    buf = InMemoryBuffer(maxlen=3)
    t0 = datetime(2026, 4, 12, 18, 0, 0, tzinfo=timezone.utc)

    buf.registrar_incidente_pendente("conv-1", "inc-100", t0)

    # 1ª mensagem posterior (1 min depois)
    u1 = buf.processar_contexto_posterior("conv-1", _make_item("pos-1", t0 + timedelta(minutes=1)))
    assert len(u1) == 1
    assert u1[0][0] == "inc-100"
    assert len(u1[0][1]) == 1

    # 2ª e 3ª mensagens posteriores
    buf.processar_contexto_posterior("conv-1", _make_item("pos-2", t0 + timedelta(minutes=2)))
    u3 = buf.processar_contexto_posterior("conv-1", _make_item("pos-3", t0 + timedelta(minutes=3)))
    assert len(u3) == 1
    assert [m["text"] for m in u3[0][1]] == ["pos-1", "pos-2", "pos-3"]

    # 4ª mensagem posterior não deve mais atualizar inc-100 (limite de 3 atingido)
    u4 = buf.processar_contexto_posterior("conv-1", _make_item("pos-4", t0 + timedelta(minutes=4)))
    assert u4 == []


def test_contexto_posterior_expira_apos_10_minutos():
    buf = InMemoryBuffer(maxlen=3)
    t0 = datetime(2026, 4, 12, 18, 0, 0, tzinfo=timezone.utc)

    buf.registrar_incidente_pendente("conv-2", "inc-200", t0)

    # Mensagem 11 minutos depois -> fora da janela de 10 minutos
    updates = buf.processar_contexto_posterior(
        "conv-2", _make_item("tarde-demais", t0 + timedelta(minutes=11))
    )
    assert updates == []
