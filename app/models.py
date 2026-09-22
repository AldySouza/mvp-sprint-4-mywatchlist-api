from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Integer, String

from app.database import Base


class Favorito(Base):
    __tablename__ = "favoritos"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, nullable=False)
    genres = Column(String, nullable=False)  # comma-separated list of genre names
    rating = Column(Integer, nullable=False)
    comment = Column(String, nullable=True)
    image_url = Column(String, nullable=True)
    external_id = Column(Integer, nullable=True)
    created_at = Column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
