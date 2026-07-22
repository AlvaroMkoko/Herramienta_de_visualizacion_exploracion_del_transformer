import math

import torch
import torch.nn as nn


class PositionalEncoding(nn.Module):

    def __init__(
        self,
        embedding_dim: int,
        max_sequence_length: int = 5000,
    ):
        super().__init__()

        position = torch.arange(
            max_sequence_length,
            dtype=torch.float32,
        ).unsqueeze(1)

        div_term = torch.exp(
            torch.arange(
                0,
                embedding_dim,
                2,
                dtype=torch.float32,
            )
            * (-math.log(10000.0) / embedding_dim)
        )

        pe = torch.zeros(
            max_sequence_length,
            embedding_dim,
        )

        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)

        pe = pe.unsqueeze(0)

        self.register_buffer("pe", pe)

    def forward(
        self,
        embeddings: torch.Tensor,
    ) -> torch.Tensor:

        sequence_length = embeddings.size(1)

        return embeddings + self.pe[:, :sequence_length]