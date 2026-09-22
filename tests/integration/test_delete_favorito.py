def test_delete_removes_from_list(client):
    created = client.post(
        "/favoritos", json={"name": "Show", "genres": ["Drama"], "rating": 3}
    ).json()

    client.delete(f"/favoritos/{created['id']}")

    listed = client.get("/favoritos").json()
    assert all(item["id"] != created["id"] for item in listed)
