"""
Tokenización de entrada/salida — wrapper sobre tiktoken.
"""

import tiktoken

ENCODINGS = [
    "o200k_base",
    "cl100k_base",
    "p50k_base",
]


class Tokenizer:
    """Wrapper sobre tiktoken.

    Expone `vocab_size` para que se use directamente al construir
    `ConfiguracionTransformer(tamano_vocabulario=tokenizer.vocab_size, ...)`,
    evitando que ese número quede hardcodeado y desincronizado del
    encoding real que se está usando.
    """

    def __init__(self, tipo_encoding: int = 1):
        if not 0 <= tipo_encoding < len(ENCODINGS):
            raise ValueError(
                f"tipo_encoding debe estar entre 0 y {len(ENCODINGS) - 1}"
            )

        self.tipo_encoding = tipo_encoding
        self.encoding = tiktoken.get_encoding(ENCODINGS[tipo_encoding])

    @property
    def vocab_size(self) -> int:
        """Tamaño real del vocabulario del encoding activo."""
        return self.encoding.n_vocab

    def encode(self, texto: str) -> list[int]:
        if not isinstance(texto, str):
            raise TypeError(f"texto debe ser str, no {type(texto).__name__}")

        return self.encoding.encode(texto)

    def decode(self, tokens: list[int]) -> str:
        # Acepta tambien tensores de torch o arrays de numpy, que es lo
        # mas comun al decodificar la salida del modelo (logits -> ids).
        if hasattr(tokens, "tolist"):
            tokens = tokens.tolist()

        if not isinstance(tokens, list):
            raise TypeError(f"tokens debe ser list, no {type(tokens).__name__}")

        return self.encoding.decode(tokens)


if __name__ == "__main__":
    tokenizer = Tokenizer(tipo_encoding=1)
    tokens = tokenizer.encode("Hola, mundo!")
    texto = tokenizer.decode(tokens)
    print(tokens)
    print(texto)
    print("vocab_size:", tokenizer.vocab_size)