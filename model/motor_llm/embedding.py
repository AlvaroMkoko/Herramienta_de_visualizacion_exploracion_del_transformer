import torch
import torch.nn as nn


class TokenEmbedding(nn.Module):

    def __init__(
        self,
        vocab_size: int,
        embedding_dim: int,
    ):
        super().__init__()

        self.embedding = nn.Embedding(
            num_embeddings=vocab_size,
            embedding_dim=embedding_dim,
        )

    def forward(
        self,
        tokens: torch.Tensor,
    ) -> torch.Tensor:

        return self.embedding(tokens)