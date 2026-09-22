def test_delete_favorito_returns_204(client):
    created = client.post(
        "/favoritos", json={"name": "Show", "genres": ["Drama"], "rating": 3}
    ).json()
    response = client.delete(f"/favoritos/{created['id']}")
    assert response.status_code == 204


def test_delete_unknown_favorito_returns_404(client):
    response = client.delete("/favoritos/9999")
    assert response.status_code == 404
