def test_update_favorito_returns_200_with_updated_fields(client):
    created = client.post(
        "/favoritos", json={"name": "Show", "genres": ["Drama"], "rating": 3}
    ).json()
    response = client.put(
        f"/favoritos/{created['id']}",
        json={"rating": 5, "comment": "Melhorou na segunda temporada"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["rating"] == 5
    assert body["comment"] == "Melhorou na segunda temporada"
    assert body["name"] == "Show"  # nome não é editável


def test_update_favorito_unknown_id_returns_404(client):
    response = client.put("/favoritos/9999", json={"rating": 4})
    assert response.status_code == 404


def test_update_favorito_invalid_rating_returns_422(client):
    created = client.post(
        "/favoritos", json={"name": "Show", "genres": ["Drama"], "rating": 3}
    ).json()
    response = client.put(f"/favoritos/{created['id']}", json={"rating": 0})
    assert response.status_code == 422


def test_update_favorito_null_comment_clears_it(client):
    created = client.post(
        "/favoritos",
        json={"name": "Show", "genres": ["Drama"], "rating": 3, "comment": "antigo"},
    ).json()
    response = client.put(
        f"/favoritos/{created['id']}", json={"rating": 3, "comment": None}
    )
    assert response.status_code == 200
    assert response.json()["comment"] is None


def test_update_favorito_omitted_fields_are_kept(client):
    created = client.post(
        "/favoritos",
        json={"name": "Show", "genres": ["Drama"], "rating": 3, "comment": "fica"},
    ).json()
    response = client.put(f"/favoritos/{created['id']}", json={"rating": 5})
    assert response.json()["comment"] == "fica"


def test_update_favorito_null_rating_returns_422(client):
    created = client.post(
        "/favoritos", json={"name": "Show", "genres": ["Drama"], "rating": 3}
    ).json()
    response = client.put(f"/favoritos/{created['id']}", json={"rating": None})
    assert response.status_code == 422
