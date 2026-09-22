def test_create_favorito_returns_201_with_shape(client):
    payload = {
        "name": "Breaking Bad",
        "genres": ["Drama", "Crime"],
        "rating": 5,
        "comment": "Obra-prima",
        "image_url": "https://example.com/img.jpg",
        "external_id": 169,
    }
    response = client.post("/favoritos", json=payload)
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Breaking Bad"
    assert body["genres"] == ["Drama", "Crime"]
    assert body["rating"] == 5
    assert body["comment"] == "Obra-prima"
    assert isinstance(body["id"], int)
    assert "created_at" in body


def test_create_favorito_missing_rating_returns_422(client):
    payload = {"name": "Breaking Bad", "genres": ["Drama"]}
    response = client.post("/favoritos", json=payload)
    assert response.status_code == 422


def test_create_favorito_rating_out_of_range_returns_422(client):
    payload = {"name": "Breaking Bad", "genres": ["Drama"], "rating": 6}
    response = client.post("/favoritos", json=payload)
    assert response.status_code == 422
