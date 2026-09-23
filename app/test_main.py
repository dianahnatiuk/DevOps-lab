from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "DevOps Lab 1 API is running"}


def test_create_item():
    response = client.post("/items/", params={"name": "test-item"})
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "test-item"
    assert "id" in data