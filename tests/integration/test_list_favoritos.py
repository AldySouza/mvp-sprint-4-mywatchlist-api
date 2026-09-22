def _create(client, **overrides):
    payload = {"name": "Show", "genres": ["Drama"], "rating": 3}
    payload.update(overrides)
    return client.post("/favoritos", json=payload).json()


def test_default_order_is_most_recently_added_first(client):
    first = _create(client, name="First")
    second = _create(client, name="Second")
    third = _create(client, name="Third")

    response = client.get("/favoritos")
    ids = [item["id"] for item in response.json()]
    assert ids == [third["id"], second["id"], first["id"]]


def test_multi_genre_favorite_matches_filter_on_any_genre(client):
    multi = _create(client, name="MultiGenre", genres=["Drama", "Fantasy"])
    _create(client, name="OnlyComedy", genres=["Comedy"])

    response = client.get("/favoritos?genre=Fantasy")
    names = [item["name"] for item in response.json()]
    assert names == ["MultiGenre"]
    assert response.json()[0]["id"] == multi["id"]
