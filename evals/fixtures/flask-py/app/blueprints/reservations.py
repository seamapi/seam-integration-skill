from flask import Blueprint, jsonify, request

from services.reservation_service import (
    cancel_reservation,
    create_reservation,
    get_reservation,
    update_reservation,
)

reservations_bp = Blueprint("reservations", __name__, url_prefix="/api/reservations")


@reservations_bp.route("", methods=["POST"])
def create():
    try:
        reservation = create_reservation(request.json)
        return jsonify({"reservation": reservation}), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 400


@reservations_bp.route("/<reservation_id>", methods=["PUT"])
def update(reservation_id):
    try:
        reservation = update_reservation(reservation_id, request.json)
        return jsonify({"reservation": reservation}), 200
    except LookupError as e:
        return jsonify({"error": str(e)}), 404


@reservations_bp.route("/<reservation_id>", methods=["DELETE"])
def cancel(reservation_id):
    try:
        reservation = cancel_reservation(reservation_id)
        return jsonify({"reservation": reservation}), 200
    except LookupError as e:
        return jsonify({"error": str(e)}), 404


@reservations_bp.route("/<reservation_id>", methods=["GET"])
def get(reservation_id):
    try:
        reservation = get_reservation(reservation_id)
        return jsonify({"reservation": reservation}), 200
    except LookupError as e:
        return jsonify({"error": str(e)}), 404
