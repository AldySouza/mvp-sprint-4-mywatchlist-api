import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# No Docker aponta para /app/data (volume), preservando os dados entre execuções.
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./favoritos.db")

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
