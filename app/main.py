"""Task API: the application that the Jenkins pipeline builds, tests and ships."""
import os

from flask import Flask, jsonify, request

APP_VERSION = os.getenv("APP_VERSION", "dev")


def create_app() -> Flask:
    app = Flask(__name__)
    tasks: dict[int, dict] = {}
    counter = {"next": 1}

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/version")
    def version():
        return jsonify(version=APP_VERSION)

    @app.get("/tasks")
    def list_tasks():
        done = request.args.get("done")
        items = list(tasks.values())
        if done in ("true", "false"):
            items = [t for t in items if t["done"] == (done == "true")]
        return jsonify(items)

    @app.post("/tasks")
    def create_task():
        body = request.get_json(silent=True) or {}
        title = (body.get("title") or "").strip()
        if not title:
            return jsonify(error="title is required"), 400
        task = {"id": counter["next"], "title": title, "done": False}
        tasks[task["id"]] = task
        counter["next"] += 1
        return jsonify(task), 201

    @app.patch("/tasks/<int:task_id>")
    def update_task(task_id: int):
        task = tasks.get(task_id)
        if task is None:
            return jsonify(error="task not found"), 404
        body = request.get_json(silent=True) or {}
        if "done" in body:
            if not isinstance(body["done"], bool):
                return jsonify(error="done must be true or false"), 400
            task["done"] = body["done"]
        if "title" in body:
            title = (body["title"] or "").strip()
            if not title:
                return jsonify(error="title cannot be empty"), 400
            task["title"] = title
        return jsonify(task)

    @app.delete("/tasks/<int:task_id>")
    def delete_task(task_id: int):
        if tasks.pop(task_id, None) is None:
            return jsonify(error="task not found"), 404
        return "", 204

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
