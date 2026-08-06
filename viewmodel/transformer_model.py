"""Data model for the interactive Transformer architecture scene.

The scene and the QML inspector both consume this module.  Keeping the copy and
colors here prevents the visual layer from becoming the application's source of
truth when component-specific screens are added later.
"""

from __future__ import annotations

from dataclasses import dataclass


Color = tuple[float, float, float, float]


@dataclass(frozen=True, slots=True)
class ComponentSpec:
    component_id: str
    title: str
    group: str
    description: str
    parameters: tuple[str, ...]
    color: Color

    @property
    def accent_hex(self) -> str:
        red, green, blue, _ = self.color
        return f"#{round(red * 255):02x}{round(green * 255):02x}{round(blue * 255):02x}"


COLORS: dict[str, Color] = {
    "embedding": (0.91, 0.52, 0.54, 1.0),
    "attention": (0.96, 0.69, 0.25, 1.0),
    "masked_attention": (0.88, 0.42, 0.58, 1.0),
    "normalization": (0.55, 0.47, 0.92, 1.0),
    "feed_forward": (0.31, 0.75, 0.52, 1.0),
    "projection": (0.35, 0.58, 0.88, 1.0),
    "output": (0.28, 0.74, 0.58, 1.0),
    "positional": (0.44, 0.36, 0.85, 1.0),
}


COMPONENTS: dict[str, ComponentSpec] = {
    "input_embedding": ComponentSpec(
        "input_embedding",
        "Input Embedding",
        "Encoder input",
        "Maps every input token to a learned d_model-dimensional vector.",
        ("Vocabulary size", "Embedding dimension (d_model)", "Padding index"),
        COLORS["embedding"],
    ),
    "encoder_positional_encoding": ComponentSpec(
        "encoder_positional_encoding",
        "Positional Encoding",
        "Encoder input",
        "Adds position information to the input embeddings before the encoder stack.",
        ("Maximum sequence length", "Encoding type", "Dropout"),
        COLORS["positional"],
    ),
    "encoder_self_attention": ComponentSpec(
        "encoder_self_attention",
        "Multi-Head Self-Attention",
        "Encoder layer",
        "Lets each input position attend to every other input position in parallel.",
        ("Number of heads", "Key/query dimension", "Attention dropout"),
        COLORS["attention"],
    ),
    "encoder_add_norm_attention": ComponentSpec(
        "encoder_add_norm_attention",
        "Add & Norm",
        "Encoder layer",
        "Combines the attention output with its residual input, then applies layer normalization.",
        ("Normalization epsilon", "Learnable scale", "Learnable bias"),
        COLORS["normalization"],
    ),
    "encoder_feed_forward": ComponentSpec(
        "encoder_feed_forward",
        "Feed Forward",
        "Encoder layer",
        "Applies the same two-layer position-wise network independently to every token.",
        ("Hidden dimension (d_ff)", "Activation", "Dropout"),
        COLORS["feed_forward"],
    ),
    "encoder_add_norm_ffn": ComponentSpec(
        "encoder_add_norm_ffn",
        "Add & Norm",
        "Encoder layer",
        "Adds the feed-forward residual connection and normalizes the encoder representation.",
        ("Normalization epsilon", "Learnable scale", "Learnable bias"),
        COLORS["normalization"],
    ),
    "output_embedding": ComponentSpec(
        "output_embedding",
        "Output Embedding",
        "Decoder input",
        "Embeds the previously generated output tokens after shifting them one position right.",
        ("Vocabulary size", "Embedding dimension (d_model)", "Weight tying"),
        COLORS["embedding"],
    ),
    "decoder_positional_encoding": ComponentSpec(
        "decoder_positional_encoding",
        "Positional Encoding",
        "Decoder input",
        "Adds position information to the shifted output embeddings.",
        ("Maximum sequence length", "Encoding type", "Dropout"),
        COLORS["positional"],
    ),
    "decoder_masked_attention": ComponentSpec(
        "decoder_masked_attention",
        "Masked Multi-Head Attention",
        "Decoder layer",
        "Uses a causal mask so a position cannot inspect tokens that come after it.",
        ("Number of heads", "Causal mask", "Attention dropout"),
        COLORS["masked_attention"],
    ),
    "decoder_add_norm_masked": ComponentSpec(
        "decoder_add_norm_masked",
        "Add & Norm",
        "Decoder layer",
        "Applies the first decoder residual connection and layer normalization.",
        ("Normalization epsilon", "Learnable scale", "Learnable bias"),
        COLORS["normalization"],
    ),
    "decoder_cross_attention": ComponentSpec(
        "decoder_cross_attention",
        "Encoder-Decoder Attention",
        "Decoder layer",
        "Uses decoder states as queries and the encoder output as keys and values.",
        ("Number of heads", "Key/value source", "Attention dropout"),
        COLORS["attention"],
    ),
    "decoder_add_norm_cross": ComponentSpec(
        "decoder_add_norm_cross",
        "Add & Norm",
        "Decoder layer",
        "Combines cross-attention with its residual stream and normalizes the result.",
        ("Normalization epsilon", "Learnable scale", "Learnable bias"),
        COLORS["normalization"],
    ),
    "decoder_feed_forward": ComponentSpec(
        "decoder_feed_forward",
        "Feed Forward",
        "Decoder layer",
        "Applies the decoder's position-wise two-layer network.",
        ("Hidden dimension (d_ff)", "Activation", "Dropout"),
        COLORS["feed_forward"],
    ),
    "decoder_add_norm_ffn": ComponentSpec(
        "decoder_add_norm_ffn",
        "Add & Norm",
        "Decoder layer",
        "Adds the final decoder residual connection and normalizes the representation.",
        ("Normalization epsilon", "Learnable scale", "Learnable bias"),
        COLORS["normalization"],
    ),
    "linear": ComponentSpec(
        "linear",
        "Linear",
        "Output head",
        "Projects each decoder state from d_model to one score per vocabulary token.",
        ("Input dimension", "Vocabulary size", "Bias"),
        COLORS["projection"],
    ),
    "softmax": ComponentSpec(
        "softmax",
        "Softmax",
        "Output head",
        "Converts vocabulary scores into a normalized probability distribution.",
        ("Axis", "Temperature", "Numerical stability"),
        COLORS["output"],
    ),
}

