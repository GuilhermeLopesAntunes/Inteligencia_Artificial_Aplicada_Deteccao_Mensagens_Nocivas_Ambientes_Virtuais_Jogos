import re
from typing import Pattern


class DetectorDeLinks:
    """
    Detector de links externos usando regex determinístico.
    Identifica URLs no formato http://, https://, www., domínios com caminho (/...) ou IPs com caminho (case-insensitive).
    """

    _PATTERN_LINK: Pattern = re.compile(
        r"(?:https?://\S+|www\.\S+|\b(?<!@)(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}/\S+|\b\d{1,3}(?:\.\d{1,3}){3}/\S+)",
        re.IGNORECASE,
    )

    def __init__(self):
        self.url_regex = self._PATTERN_LINK

    @classmethod
    def detectar_link(cls, texto: str) -> bool:
        """
        Detecta se o texto contém algum link externo.
        """
        if not texto or not isinstance(texto, str):
            return False
        return bool(cls._PATTERN_LINK.search(texto))

    def has_link(self, texto: str) -> bool:
        """
        Retorna True se o texto contiver um link externo, False caso contrário.
        """
        return self.detectar_link(texto)