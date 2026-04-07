import uuid

from models.booking import Member, RoomBooking
from models.room import Room

# In-memory data store
rooms = [
    Room(id="room-a1", name="Focus Room A1", capacity=1, floor=1),
    Room(id="room-b2", name="Meeting Room B2", capacity=6, floor=2),
    Room(id="room-c3", name="Board Room C3", capacity=12, floor=3),
]

members: list[Member] = []

bookings: list[RoomBooking] = []


def generate_id() -> str:
    return str(uuid.uuid4())


def find_room(room_id: str) -> Room | None:
    return next((r for r in rooms if r.id == room_id), None)


def find_member(member_id: str) -> Member | None:
    return next((m for m in members if m.id == member_id), None)
