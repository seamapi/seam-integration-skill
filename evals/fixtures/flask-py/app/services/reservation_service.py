from models import store
from models.reservation import Guest, Reservation


def _reservation_to_dict(r: Reservation) -> dict:
    return {
        "id": r.id,
        "guest_id": r.guest_id,
        "unit_id": r.unit_id,
        "check_in": r.check_in,
        "check_out": r.check_out,
        "status": r.status,
    }


def create_reservation(data: dict) -> dict:
    unit_id = data.get("unit_id")
    unit = store.find_unit(unit_id)
    if not unit:
        raise ValueError(f"Unit {unit_id} not found")

    guest_email = data.get("guest_email")
    guest_name = data.get("guest_name")

    # Find existing guest by email or create new one
    guest = next((g for g in store.guests if g.email == guest_email), None)
    if not guest:
        guest = Guest(id=store.generate_id(), name=guest_name, email=guest_email)
        store.guests.append(guest)

    reservation = Reservation(
        id=store.generate_id(),
        guest_id=guest.id,
        unit_id=unit_id,
        check_in=data.get("check_in"),
        check_out=data.get("check_out"),
        status="confirmed",
    )
    store.reservations.append(reservation)

    return _reservation_to_dict(reservation)


def update_reservation(reservation_id: str, data: dict) -> dict:
    reservation = next(
        (r for r in store.reservations if r.id == reservation_id), None
    )
    if not reservation:
        raise LookupError(f"Reservation {reservation_id} not found")

    if "check_in" in data:
        reservation.check_in = data["check_in"]
    if "check_out" in data:
        reservation.check_out = data["check_out"]

    return _reservation_to_dict(reservation)


def cancel_reservation(reservation_id: str) -> dict:
    reservation = next(
        (r for r in store.reservations if r.id == reservation_id), None
    )
    if not reservation:
        raise LookupError(f"Reservation {reservation_id} not found")

    reservation.status = "cancelled"

    return _reservation_to_dict(reservation)


def get_reservation(reservation_id: str) -> dict:
    reservation = next(
        (r for r in store.reservations if r.id == reservation_id), None
    )
    if not reservation:
        raise LookupError(f"Reservation {reservation_id} not found")

    return _reservation_to_dict(reservation)
