def test_created_favorito_appears_in_list_with_saved_fields(client):
    payload = {
        "name": "Fringe",
        "genres": ["Drama", "Science-Fiction"],
        "rating": 4,
        "comment": "Rewatch pra sempre",
    }
    create_response = client.post("/favoritos", json=payload)
    assert create_response.status_code == 201
    created_id = create_response.json()["id"]

    list_response = client.get("/favoritos")
    assert list_response.status_code == 200
    items = list_response.json()
    assert any(
        item["id"] == created_id
        and item["name"] == "Fringe"
        and item["genres"] == ["Drama", "Science-Fiction"]
        and item["rating"] == 4
        and item["comment"] == "Rewatch pra sempre"
        for item in items
    )
