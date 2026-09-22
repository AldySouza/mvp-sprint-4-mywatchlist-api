from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator


def _split_genres(value):
    """Accepts either a list (client JSON) or the CSV string stored in the DB."""
    if isinstance(value, str):
        return [g.strip() for g in value.split(",") if g.strip()]
    return value


class FavoritoCreate(BaseModel):
    name: str = Field(min_length=1)
    genres: List[str] = Field(min_length=1)
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = None
    image_url: Optional[str] = None
    external_id: Optional[int] = None

    @field_validator("genres", mode="before")
    @classmethod
    def normalize_genres(cls, value):
        return _split_genres(value)


class FavoritoUpdate(BaseModel):
    """Only rating and/or comment are editable."""

    # Omitido = mantém o valor atual. `rating: null` é rejeitado (422);
    # `comment: null` apaga o comentário.
    rating: int = Field(default=None, ge=1, le=5)
    comment: Optional[str] = None


class Favorito(BaseModel):
    id: int
    name: str
    genres: List[str]
    rating: int
    comment: Optional[str] = None
    image_url: Optional[str] = None
    external_id: Optional[int] = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("genres", mode="before")
    @classmethod
    def normalize_genres(cls, value):
        return _split_genres(value)


class GeneroCount(BaseModel):
    genero: str
    total: int


class Estatisticas(BaseModel):
    total: int
    media_notas: Optional[float] = None
    por_nota: dict[int, int]
    por_genero: List[GeneroCount]
