import tiktoken

"""
Tokenización de entrada/salida.

TODO:
- Wrapper sobre tiktoken o tokenizador propio tipo nano-GPT (BPE simple).
- encode(text) -> list[int]
- decode(tokens) -> str
"""

ENCODINGS = [
    "o200k_base",
    "cl100k_base",
    "p50k_base",
]



class Tokenizer:

    def __init__(self, tipo_encoding: int = 1):
        if not 0 <= tipo_encoding < len(ENCODINGS):
            raise ValueError(
                f"tipo_encoding debe estar entre "
                f"0 y {len(ENCODINGS) - 1}"
            )

        self.tipo_encoding = tipo_encoding
        self.encoding = tiktoken.get_encoding(
            ENCODINGS[tipo_encoding]
        )

    def encode(self, texto: str) -> list[int]:
        if not isinstance(texto, str):
            raise TypeError(
                f"texto debe ser str, no "
                f"{type(texto).__name__}"
            )

        return self.encoding.encode(texto)

    def decode(self, tokens: list[int]) -> str:
        if not isinstance(tokens, list):
            raise TypeError(
                f"tokens debe ser list, no "
                f"{type(tokens).__name__}"
            )

        return self.encoding.decode(tokens)
    

tokenizer = Tokenizer(tipo_encoding=1)

tokens = tokenizer.encode("Hola mundo")

texto = tokenizer.decode(tokens)

print(tokens)
print(texto)