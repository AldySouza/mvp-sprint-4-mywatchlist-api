def test_estatisticas_lista_vazia(client):
    response = client.get("/favoritos/estatisticas")
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 0
    assert body["media_notas"] is None
    assert body["por_genero"] == []
    assert body["por_nota"] == {str(n): 0 for n in range(1, 6)}


def test_estatisticas_agrega_notas_e_generos(client):
    client.post("/favoritos", json={"name": "A", "genres": ["Drama", "Crime"], "rating": 5})
    client.post("/favoritos", json={"name": "B", "genres": ["Drama"], "rating": 2})

    body = client.get("/favoritos/estatisticas").json()
    assert body["total"] == 2
    assert body["media_notas"] == 3.5
    assert body["por_nota"]["5"] == 1 and body["por_nota"]["2"] == 1
    assert body["por_genero"][0] == {"genero": "Drama", "total": 2}
    assert {"genero": "Crime", "total": 1} in body["por_genero"]
