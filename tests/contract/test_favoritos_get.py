def _create(client, **overrides):
    payload = {"name": "Show", "genres": ["Drama"], "rating": 3}
    payload.update(overrides)
    return client.post("/favoritos", json=payload).json()


def test_list_favoritos_returns_200_and_array(client):
    response = client.get("/favoritos")
    assert response.status_code == 200
    assert response.json() == []


def test_list_favoritos_sort_by_rating(client):
    _create(client, name="Low", rating=1)
    _create(client, name="High", rating=5)
    response = client.get("/favoritos?sort_by=rating")
    assert response.status_code == 200
    names = [item["name"] for item in response.json()]
    assert names == ["High", "Low"]


def test_list_favoritos_filter_by_genre(client):
    _create(client, name="DramaShow", genres=["Drama"])
    _create(client, name="ComedyShow", genres=["Comedy"])
    response = client.get("/favoritos?genre=Comedy")
    assert response.status_code == 200
    names = [item["name"] for item in response.json()]
    assert names == ["ComedyShow"]


def test_list_favoritos_genre_and_sort_combined(client):
    _create(client, name="ComedyLow", genres=["Comedy"], rating=2)
    _create(client, name="ComedyHigh", genres=["Comedy"], rating=5)
    _create(client, name="DramaHigh", genres=["Drama"], rating=5)
    response = client.get("/favoritos?genre=Comedy&sort_by=rating")
    assert response.status_code == 200
    names = [item["name"] for item in response.json()]
    assert names == ["ComedyHigh", "ComedyLow"]
