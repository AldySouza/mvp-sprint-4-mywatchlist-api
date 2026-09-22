def test_update_persists_and_reflects_in_list(client):
    created = client.post(
        "/favoritos", json={"name": "Show", "genres": ["Drama"], "rating": 2}
    ).json()

    client.put(f"/favoritos/{created['id']}", json={"rating": 5, "comment": "top"})

    listed = client.get("/favoritos").json()
    updated = next(item for item in listed if item["id"] == created["id"])
    assert updated["rating"] == 5
    assert updated["comment"] == "top"
