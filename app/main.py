from collections import Counter
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app import models, schemas
from app.database import Base, SessionLocal, engine, get_db

Base.metadata.create_all(bind=engine)

# Popula o banco com séries de exemplo (dados reais da TVMaze) na primeira
# execução, para o usuário ver a listagem preenchida sem precisar cadastrar.
_SEED_FAVORITOS = [
    dict(
        external_id=169,
        name="Breaking Bad",
        genres="Drama,Crime,Thriller",
        rating=5,
        comment="Um dos maiores dramas já feitos.",
        image_url="https://static.tvmaze.com/uploads/images/medium_portrait/501/1253519.jpg",
    ),
    dict(
        external_id=82,
        name="Game of Thrones",
        genres="Drama,Adventure,Fantasy",
        rating=4,
        comment="Ótimo até certo ponto.",
        image_url="https://static.tvmaze.com/uploads/images/medium_portrait/498/1245274.jpg",
    ),
    dict(
        external_id=431,
        name="Friends",
        genres="Comedy,Romance",
        rating=5,
        comment="Clássico pra assistir sempre.",
        image_url="https://static.tvmaze.com/uploads/images/medium_portrait/41/104565.jpg",
    ),
    dict(
        external_id=526,
        name="The Office",
        genres="Comedy",
        rating=4,
        comment=None,
        image_url="https://static.tvmaze.com/uploads/images/medium_portrait/481/1204342.jpg",
    ),
    dict(
        external_id=2993,
        name="Stranger Things",
        genres="Drama,Horror,Science-Fiction",
        rating=4,
        comment="Nostalgia anos 80.",
        image_url="https://static.tvmaze.com/uploads/images/medium_portrait/595/1489169.jpg",
    ),
]


def _seed_favoritos():
    db = SessionLocal()
    try:
        if db.query(models.Favorito).first() is not None:
            return
        db.add_all(models.Favorito(**data) for data in _SEED_FAVORITOS)
        db.commit()
    finally:
        db.close()


_seed_favoritos()

app = FastAPI(
    title="MyWatchList API",
    description="API de favoritos do MyWatchList — ver /docs para o Swagger UI.",
    version="1.0.0",
)

# Frontend roda em origem diferente (porta 3001) e chama esta API (porta 8000)
# diretamente do navegador — CORS precisa estar liberado.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/favoritos", response_model=schemas.Favorito, status_code=201)
def create_favorito(favorito: schemas.FavoritoCreate, db: Session = Depends(get_db)):
    db_favorito = models.Favorito(
        name=favorito.name,
        genres=",".join(favorito.genres),
        rating=favorito.rating,
        comment=favorito.comment,
        image_url=favorito.image_url,
        external_id=favorito.external_id,
    )
    db.add(db_favorito)
    db.commit()
    db.refresh(db_favorito)
    return db_favorito


@app.delete("/favoritos/{favorito_id}", status_code=204)
def delete_favorito(favorito_id: int, db: Session = Depends(get_db)):
    db_favorito = db.get(models.Favorito, favorito_id)
    if db_favorito is None:
        raise HTTPException(status_code=404, detail="Favorito não encontrado")
    db.delete(db_favorito)
    db.commit()
    return None


@app.get("/favoritos", response_model=list[schemas.Favorito])
def list_favoritos(
    sort_by: Optional[str] = Query(default=None, pattern="^rating$"),
    genre: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    # Default order: most-recently-added first.
    query = db.query(models.Favorito).order_by(models.Favorito.created_at.desc())
    items = query.all()

    if genre:
        genre_lower = genre.strip().lower()
        items = [
            item
            for item in items
            if genre_lower in [g.strip().lower() for g in item.genres.split(",")]
        ]

    if sort_by == "rating":
        # Highest rating first, fixed order.
        items = sorted(items, key=lambda item: item.rating, reverse=True)

    return items


@app.get("/favoritos/estatisticas", response_model=schemas.Estatisticas)
def estatisticas_favoritos(db: Session = Depends(get_db)):
    """Resumo da lista para o painel do front: total, média, distribuição de notas e gêneros."""
    items = db.query(models.Favorito).all()
    ratings = [item.rating for item in items]
    genres = Counter(
        g.strip() for item in items for g in item.genres.split(",") if g.strip()
    )
    return schemas.Estatisticas(
        total=len(items),
        media_notas=round(sum(ratings) / len(ratings), 2) if ratings else None,
        por_nota={nota: ratings.count(nota) for nota in range(1, 6)},
        por_genero=[
            schemas.GeneroCount(genero=g, total=n) for g, n in genres.most_common()
        ],
    )


@app.put("/favoritos/{favorito_id}", response_model=schemas.Favorito)
def update_favorito(
    favorito_id: int, favorito: schemas.FavoritoUpdate, db: Session = Depends(get_db)
):
    db_favorito = db.get(models.Favorito, favorito_id)
    if db_favorito is None:
        raise HTTPException(status_code=404, detail="Favorito não encontrado")

    for field, value in favorito.model_dump(exclude_unset=True).items():
        setattr(db_favorito, field, value)

    db.commit()
    db.refresh(db_favorito)
    return db_favorito
