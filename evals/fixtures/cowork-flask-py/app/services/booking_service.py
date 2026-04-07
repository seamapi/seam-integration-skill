from models import store
from models.booking import Member, RoomBooking


def _booking_to_dict(b: RoomBooking) -> dict:
    return {
        "id": b.id,
        "member_id": b.member_id,
        "room_id": b.room_id,
        "start_time": b.start_time,
        "end_time": b.end_time,
        "status": b.status,
    }


def create_booking(data: dict) -> dict:
    room_id = data.get("room_id")
    room = store.find_room(room_id)
    if not room:
        raise ValueError(f"Room {room_id} not found")

    member_email = data.get("member_email")
    member_name = data.get("member_name")
    member_company = data.get("member_company", "")

    # Find existing member by email or create new one
    member = next((m for m in store.members if m.email == member_email), None)
    if not member:
        member = Member(
            id=store.generate_id(),
            name=member_name,
            email=member_email,
            company=member_company,
        )
        store.members.append(member)

    booking = RoomBooking(
        id=store.generate_id(),
        member_id=member.id,
        room_id=room_id,
        start_time=data.get("start_time"),
        end_time=data.get("end_time"),
        status="active",
    )
    store.bookings.append(booking)

    return _booking_to_dict(booking)


def update_booking(booking_id: str, data: dict) -> dict:
    booking = next((b for b in store.bookings if b.id == booking_id), None)
    if not booking:
        raise LookupError(f"Booking {booking_id} not found")

    if "start_time" in data:
        booking.start_time = data["start_time"]
    if "end_time" in data:
        booking.end_time = data["end_time"]

    return _booking_to_dict(booking)


def cancel_booking(booking_id: str) -> dict:
    booking = next((b for b in store.bookings if b.id == booking_id), None)
    if not booking:
        raise LookupError(f"Booking {booking_id} not found")

    booking.status = "cancelled"

    return _booking_to_dict(booking)


def get_booking(booking_id: str) -> dict:
    booking = next((b for b in store.bookings if b.id == booking_id), None)
    if not booking:
        raise LookupError(f"Booking {booking_id} not found")

    return _booking_to_dict(booking)
