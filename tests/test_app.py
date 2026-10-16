import pytest

from app.main import create_app


@pytest.fixture()
def client():
    return create_app().test_client()


def add(client, title="write tests"):
    return client.post("/tasks", json={"title": title})


def test_health_and_version(client):
    assert client.get("/health").get_json() == {"status": "ok"}
    assert "version" in client.get("/version").get_json()


def test_create_task(client):
    res = add(client)
    assert res.status_code == 201
    assert res.get_json() == {"id": 1, "title": "write tests", "done": False}


def test_create_requires_title(client):
    assert client.post("/tasks", json={}).status_code == 400
    assert client.post("/tasks", json={"title": "   "}).status_code == 400


def test_list_and_filter(client):
    add(client, "a")
    add(client, "b")
    client.patch("/tasks/1", json={"done": True})
    assert len(client.get("/tasks").get_json()) == 2
    assert [t["title"] for t in client.get("/tasks?done=true").get_json()] == ["a"]
    assert [t["title"] for t in client.get("/tasks?done=false").get_json()] == ["b"]


def test_update_task(client):
    add(client)
    res = client.patch("/tasks/1", json={"title": "renamed", "done": True})
    assert res.get_json() == {"id": 1, "title": "renamed", "done": True}


def test_update_validation(client):
    add(client)
    assert client.patch("/tasks/1", json={"done": "yes"}).status_code == 400
    assert client.patch("/tasks/1", json={"title": " "}).status_code == 400
    assert client.patch("/tasks/99", json={"done": True}).status_code == 404


def test_delete_task(client):
    add(client)
    assert client.delete("/tasks/1").status_code == 204
    assert client.delete("/tasks/1").status_code == 404
    assert client.get("/tasks").get_json() == []


def test_ids_keep_increasing_after_delete(client):
    add(client)
    client.delete("/tasks/1")
    assert add(client).get_json()["id"] == 2
